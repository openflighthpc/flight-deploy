module Profile
  class QueueMonitor
    def enqueue(name:, identity:)
      File.open(File.join(Config.queue_dir, "#{name}.yaml"), "w" ) do |file|
        data = {"identity" => identity}
        YAML.dump(data, file)
      end
    end
    
    def dequeue(name:)
      File.delete(File.join(Config.queue_dir, "#{name}.yaml"))
    end
    
    def in_queue?(name:)
      File.exists?(File.join(Config.queue_dir, "#{name}.yaml"))
    end

    attr_reader :pid, :queue

    def initialize
      @pid = Process.pid
    end

    private

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
    end
  end
end
