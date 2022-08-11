module Deploy
  class Node
    def self.all
      @all_nodes ||= [].tap do |a|
        Dir["#{Config.inventory_dir}/*.yaml"].each do |file|
          node = YAML.load_file(file)
          a << new(
            hostname: node['hostname'],
            profile: node['profile'],
            status: node['status'],
            deployment_pid: node[:deployment_pid]
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
        deployment_pid: deployment_pid
      }.to_h
    end

    def filepath
      File.join(Config.inventory_path, "#{hostname}.yaml")
    end

    def save
      File.open(filepath, 'w') { |f| YAML.dump(self.to_h. f) }
    end

    attr_accessor :hostname, :profile, :deployment_pid

    def initialize(hostname:, profile:, deployment_pid:)
      @hostname = hostname
      @profile = profile
      @deployment_pid = deployment_pid
    end
  end
end
