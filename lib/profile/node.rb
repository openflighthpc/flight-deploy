require 'open3'
require 'yaml'
require 'erb'
require 'net/sftp'

require_relative './hunter_cli'
require_relative './json_web_token'
require_relative './queue_manager'

module Profile
  class Node
    def self.all(include_hunter: false, reload: false)
      if reload
        return fetch_all(include_hunter: include_hunter)
      end

      @all_nodes ||= fetch_all(include_hunter: include_hunter)
    end

    def self.find(name=nil, include_hunter: false, reload: false)
      all_nodes = all(include_hunter: include_hunter, reload: reload)
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

    def self.generate(names, identity, use_hunter: false)
      names.map do |name|
        hostname =
          case use_hunter
          when true
            Node.find(name, include_hunter: true).hostname
          when false
            name
          end

        ip =
          case use_hunter
          when true
            Node.find(name, include_hunter: true).ip
          when false
            nil
          end

        Node.new(
          hostname: hostname,
          name: name,
          identity: identity,
          hunter_label: Node.find(name, include_hunter: true)&.hunter_label,
          ip: ip
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
      @log_filepath ||= file_glob.sort_by { |l| l.split(/[-.]/)[-2] }
                                 .last
    end

    def clear_logs
      Dir.glob("#{Config.log_dir}/#{name}-*.log").each do |file|
        File.delete(file) if File.symlink?(file)
      end
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
      return 'queued' if QueueManager.contains?(name)
      stdout_str, state = Open3.capture2("ps -e")
      processes = stdout_str.split("\n").map! { |p| p.split(" ") }
      running = processes.any? { |p| p[0].to_i == deployment_pid }
      if running
        case log_filepath.split("-")[-2]
        when 'remove'
          return 'removing'
        when 'apply'
          return 'applying'
        end
      elsif !exit_status || exit_status > 0
        return 'available' if hunter_label
        return 'failed'
      end

      'complete'
    end

    def fetch_identity
      Identity.find(identity, Config.cluster_type)
    end

    def destroy
      File.delete(filepath)
    end

    def jwt
      JsonWebToken.encode({"name" => name})
    end

    def install_remove_hook
      return unless fetch_identity.commands.key?('remove')

      systemd_unit = File.read(
        File.join(
          Config.root,
          'opt',
          'profile-shutdown.service'
        )
      )

      script_erb = ERB.new(
        File.read(
          File.join(
            Config.root,
            'opt',
            'shutdown.sh.erb'
          )
        )
      )

      # Not using a password; this method should only be called if the user has
      # root SSH access to the child node.
      Net::SFTP.start(ip, 'root') do |sftp|
        # Fetch headnode IP from SSH connection properties
        headnode_ip = sftp.session.exec!("echo $SSH_CONNECTION").split[0]
        erb_vars = {
          'headnode_ip' => headnode_ip,
          'child_token' => jwt
        }

        script_eval = script_erb.result(binding)

        sftp.file.open("/root/shutdown.sh", "w") do |f|
          f.puts script_eval
        end

        sftp.session.exec! 'chmod +x /root/shutdown.sh'

        sftp.file.open("/etc/systemd/system/profile-shutdown.service", "w") do |f|
          f.puts systemd_unit
        end

        # May as well reuse the SFTP's Net::SSH session object instead of
        # closing and reopening a new one.
        # NB: We don't get standard output from these commands.
        sftp.session.exec! "systemctl daemon-reload"
        sftp.session.exec! "systemctl start profile-shutdown"
      end
    end

    def dependencies
      fetch_identity.dependencies
    end

    def conflicts
      fetch_identity.conflicts
    end

    def conflicts_with?(identity)
      conflicts.include?(identity)
    end

    def conflicts_satisfied?(nodes)
      nodes.none? do |existing|
        next unless existing.identity

        conflicts_with?(existing.identity)
      end
    end

    def dependencies_satisfied?(nodes)
      dependencies.all? { |dep| nodes.map(&:identity).include?(dep) }
    end

    def errors
      @errors ||= []
    end

    def full_errors
      errors.map { |e| "'#{name}' #{e}"}.join("\n")
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

    private

    def self.fetch_all(include_hunter:)
      a = [].tap do |a|
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
  end
end
