require 'open3'
require 'yaml'

require_relative './hunter_cli'

module Profile
  class Node
    def self.all(include_hunter: false)
      @all_nodes ||= [].tap do |a|
        Dir["#{Config.inventory_dir}/*.yaml"].each do |file|
          node = YAML.load_file(file)
          a << new(
            hostname: node['hostname'],
            identity: node['identity'],
            deployment_pid: node['deployment_pid'],
            exit_status: node['exit_status'],
            name: File.basename(file, '.*'),
            ip: node['ip']
          )
        end
        if include_hunter
          hunter_nodes = list_hunter_nodes.reject do |node|
            a.any? { |e| e.name == node.hunter_label }
          end
          a.concat(hunter_nodes)
        end
      end.sort_by { |n| [n.hunter_label || n.hostname ] }
    end

    def self.find(name=nil, include_hunter: false)
      all_nodes = all(include_hunter: include_hunter)
      all_nodes.find do |node|
        node.name == name
      end
    end

    def self.save_all
      Node.all.map(&:save)
    end

    def self.list_hunter_nodes
      result = HunterCLI.list_nodes
      result.split("\n").map do |line|
        parts = line.split("\t").map { |p| p.empty? ? nil : p }
        new(
          hostname: parts[1],
          hunter_label: parts[4],
          ip: parts[2]
        )
      end
    end

    def to_h
      {
        'hostname' => hostname,
        'identity' => identity,
        'deployment_pid' => deployment_pid,
        'exit_status' => exit_status,
        'ip' => ip
      }
    end

    def filepath
      File.join(Config.inventory_dir, "#{name}.yaml")
    end

    def log_file
      @log_file ||= File.open(log_filepath)
    end

    def log_filepath
      file_glob = Dir.glob("#{Config.log_dir}/#{name}-*.log")
      raise "No log file exists for this node" if file_glob.empty?
      @log_filepath ||= file_glob.sort
                                 .last
    end

    def commands
      log = File.read(log_filepath)
      commands = log.split(/(?=PROFILE_COMMAND)/)
      commands.map do |cmd|
        name = cmd.scan(/(?<=PROFILE_COMMAND ).*?(?=:)/)
        value = cmd.sub /^PROFILE_COMMAND .*: /, ''
        { name => value }
      end
    end

    def save
      File.open(filepath, 'w+') { |f| YAML.dump(self.to_h, f) }
    end

    def delete
      File.delete(filepath) if File.exist?(filepath)
      inventory = Inventory.load(Type.find(Config.cluster_type).fetch_answer("cluster_name"))
      inventory.remove_node(self, Identity.find(identity, Config.cluster_type).group_name)
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
      return 'available' if hunter_label
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

    def fetch_identity
      Identity.find(identity, Config.cluster_type)
    end

    attr_reader :name
    attr_accessor :hostname, :identity, :deployment_pid, :exit_status, :hunter_label, :ip

    def initialize(hostname:, identity: nil, deployment_pid: nil, exit_status: nil, hunter_label: nil, name: nil, ip: nil)
      @hostname = hostname
      @identity = identity
      @deployment_pid = deployment_pid
      @exit_status = exit_status
      @hunter_label = hunter_label
      @name = name || hunter_label || hostname
      @ip = ip
    end
  end
end
