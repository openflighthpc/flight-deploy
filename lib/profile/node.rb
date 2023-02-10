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
            identity_name: node['identity_name'],
            deployment_pid: node['deployment_pid'],
            exit_status: node['exit_status'],
            name: File.basename(file, '.*'),
            ip: node['ip'],
            groups: node['groups']
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
          ip: parts[2],
          groups: parts[3].split("|"),
          hunter_label: parts[4]
        )
      end
    end

    def to_h
      {
        'hostname' => hostname,
        'identity_name' => identity_name,
        'deployment_pid' => deployment_pid,
        'exit_status' => exit_status,
        'ip' => ip,
        'groups' => groups
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
      inventory.remove_node(self, Identity.find(identity_name, Config.config.cluster_type).group_name)
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
    
    def apply_identity(identity, cluster_type)
      identity_name = identity.name
      cmds = identity.commands

      inventory = Inventory.load(Type.find(Config.cluster_type).fetch_answer("cluster_name"))
      inventory.groups[identity.group_name] ||= []
      inv_file = inventory.filepath

      env = {
        "ANSIBLE_DISPLAY_SKIPPED_HOSTS" => "false",
        "ANSIBLE_HOST_KEY_CHECKING" => "false",
        "INVFILE" => inv_file,
        "RUN_ENV" => cluster_type.run_env
      }.tap do |e|
        cluster_type.questions.each do |q|
          e[q.env] = cluster_type.fetch_answer(q.id).to_s
        end
      end

      if Config.use_hunter?
        inv_row = "#{hostname} ansible_host=#{ip}"
      else
        inv_row = "#{hostname}"
      end
      inventory.groups[identity.group_name] |= [inv_row]
      inventory.dump

      pid = Process.fork do
        log_name = "#{Config.log_dir}/#{name}-#{Time.now.to_i}.log"

        last_exit = cmds.each do |command|
          sub_pid = Process.spawn(
            env.merge( { "NODE" => hostname} ),
            "echo PROFILE_COMMAND #{command[:name]}: #{command[:value]}; #{command[:value]}",
            [:out, :err] => [log_name, "a+"],
          )
          Process.wait(sub_pid)
          exit_status = $?.exitstatus

          if exit_status != 0
            break exit_status
          end

          if command == cmds.last && exit_status == 0
            break exit_status
          end
        end
        update(deployment_pid: nil, exit_status: last_exit)
      end
      update(deployment_pid: pid)
      Process.detach(pid)
    end
    
    def find_identity(cluster_type)
      groups.each do |group|
        identity = cluster_type.find_identity(group)
        if identity
          return identity
        end
      end
      nil
    end

    attr_reader :name
    attr_accessor :hostname, :identity_name, :deployment_pid, :exit_status, :hunter_label, :ip, :groups

    def initialize(hostname:, identity_name: nil, deployment_pid: nil, exit_status: nil, hunter_label: nil, name: nil, ip: nil, groups: [])
      @hostname = hostname
      @identity_name = identity_name
      @deployment_pid = deployment_pid
      @exit_status = exit_status
      @hunter_label = hunter_label
      @name = name || hunter_label || hostname
      @ip = ip
      @groups = groups
    end
  end
end
