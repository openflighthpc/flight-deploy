module Profile
  class QueueMonitor
    class << self
      def pidfile
        Config.queue_pidfile
      end

      def enqueue(name:, identity:)
        File.open(File.join(Config.queue_dir, "#{name}.yaml"), "w" ) do |file|
          data = {"identity" => identity}
          YAML.dump(data, file)
        end

        start_monitor unless File.file?(pidfile)
      end

      def start_monitor
        # Fork process and daemonise it so parent process can continue
        Process.fork do
          Process.daemon
          File.write(pidfile, Process.pid, 'w') 
          new.monitor
        end
      end

      def dequeue(name:)
        File.delete(File.join(Config.queue_dir, "#{name}.yaml"))
      end

      def in_queue?(name:)
        File.exists?(File.join(Config.queue_dir, "#{name}.yaml"))
      end
    end

    def monitor
      loop do
        applied_identities = Node.all.filter{|node| node.status == "complete"}.map(&:identity)
        current_queue = []
        to_apply = []
        Dir["#{Config.queue_dir}/*.yaml"].each do |file|
          entry = YAML.load_file(file)
          identity = cluster_type.find_identity(entry["identity"])
          missing = identity.dependencies - applied_identities
          if !missing.empty?
            to_apply << entry
          end
        end
        apply_jobs = {}
        to_apply.each do |entry|
          (apply_jobs[entry["identity"]] || = []) << entry["name"]
        end
        apply_jobs.each do |identity, names|
          args = [
            names.join(","),
            identity
          ]

          Commands::SendPayload.new(args, OpenStruct.new).run!
        end
        sleep(5)
      end
    ensure
      File.delete(pidfile) if File.file?(pidfile)
    end
  end
end
