require 'open3'

module Deploy
  class Node
    def self.all
      @all_nodes ||= [].tap do |a|
        Dir["#{Config.inventory_dir}/*.yaml"].each do |file|
          node = YAML.load_file(file)
          a << new(
            hostname: node[:hostname],
            profile: node[:profile],
            deployment_pid: node[:deployment_pid],
            exit_status: node[:exit_status]
          )
        end
      end.sort_by { |n| n.hostname }
    end

    def self.find(hostname=nil)
      all.find { |node| node.hostname == hostname }
    end

    def self.save_all
      Node.all.map(&:save)
    end

    def to_h
      {
        hostname: hostname,
        profile: profile,
        deployment_pid: deployment_pid,
        exit_status: exit_status
      }.to_h
    end

    def filepath
      File.join(Config.inventory_dir, "#{hostname}.yaml")
    end

    def save
      File.open(filepath, 'w+') { |f| YAML.dump(self.to_h, f) }
    end

    def update(**kwargs)
       kwargs.each do |k, v|
         if respond_to?("#{k}=")
           public_send("#{k}=", v)
         end
       end
       save
    end

    def status
      stdout_str, state = Open3.capture2("ps -e")
      processes = stdout_str.split("\n").map! { |p| p.split(" ") }
      running = processes.any? { |p| p[0].to_i == deployment_pid }
      running ? "deploying" : "complete"
    end

    attr_accessor :hostname, :profile, :deployment_pid, :exit_status

    def initialize(hostname:, profile:, deployment_pid:, exit_status:)
      @hostname = hostname
      @profile = profile
      @deployment_pid = deployment_pid
      @exit_status = exit_status
    end
  end
end
