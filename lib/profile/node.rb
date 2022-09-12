require 'open3'

module Profile
  class Node
    def self.all
      @all_nodes ||= [].tap do |a|
        Dir["#{Config.inventory_dir}/*.yaml"].each do |file|
          node = YAML.load_file(file)
          a << new(
            hostname: node['hostname'],
            identity: node['identity'],
            deployment_pid: node['deployment_pid'],
            exit_status: node['exit_status']
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
        'hostname' => hostname,
        'identity' => identity,
        'deployment_pid' => deployment_pid,
        'exit_status' => exit_status
      }
    end

    def filepath
      File.join(Config.inventory_dir, "#{hostname}.yaml")
    end

    def log_file
      @log_file ||= File.open(log_filepath)
    end

    def log_filepath
      file_glob = Dir.glob("#{Config.log_dir}/#{hostname}-*.log")
      raise "No log file exists for this node" if file_glob.empty?
      @log_filepath ||= file_glob.sort
                                 .last
    end

    def command
      File.open(log_filepath, &:readline)
    end

    def save
      File.open(filepath, 'w+') { |f| YAML.dump(self.to_h, f) }
    end

    def delete
      File.delete(filepath) if File.exist?(filepath)
      @deleted = true
    end

    # **kwargs grabs all of the KeyWord ARGuments and puts them into a single
    # hash called `kwargs`. For each of the keys in the hash, if the Node 
    # has that key as an accessible attribute, set it to the value given for 
    # that key. `send` is a way to call a method on an object where the method
    # name is stored as a string. `public_send` is the same thing, but it's 
    # safer because it cannot call private methods.
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
      if running
        'applying'
      elsif !exit_status || exit_status > 0
        'failed'
      else
        'complete'
      end
    end

    attr_accessor :hostname, :identity, :deployment_pid, :exit_status, :deleted

    def initialize(hostname:, identity: nil, deployment_pid: nil, exit_status: nil)
      @hostname = hostname
      @identity = identity
      @deployment_pid = deployment_pid
      @exit_status = exit_status
      @deleted = false
    end
  end
end
