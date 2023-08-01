module Profile
  class QueueManager
    def self.push(name, identity)
      Queue.push(name, identity)

      unless QueueMonitor.running?
        # Fork process and daemonise it so that parent process can continue
        Process.fork do
          Process.daemon
          QueueMonitor.start
        end
      end
    end

    def self.pop(name)
      Queue.pop(name)
    end

    def self.contains?(name)
      Queue.contains?(name)
    end

    private

    # Not to be confused with Thread::Queue
    class Queue
      class << self
        def node_file(name)
          File.join(Config.queue_dir, name)
        end

        def push(name, identity)
          File.open(node_file(name), 'w') do |file|
            file.write(identity)
          end
        end

        def pop(*names)
          names.each do |name|
            next unless contains?(name)
            File.delete(node_file(name))
          end
        end

        def contains?(name)
          File.exists?(node_file(name))
        end

        def index
          Dir[node_file('*')].map do |f|
            { name: File.basename(f), identity: File.read(f) }
          end
        end
      end
    end

    class QueueMonitor
      class << self
        def pidfile
          Config.queue_pidfile
        end

        def pid
          running? && File.read(pidfile)
        end

        def running?
          File.file?(pidfile)
        end

        def start
          File.write(pidfile, Process.pid)

          until Queue.index.empty?
            grouped = Queue.index.group_by { |n| n[:identity] }
            grouped.each do |group, nodes|
              names = nodes.map { |n| n[:name] }

              Queue.pop(names)

              args = [
                names.join(','),
                group
              ]

              begin
                Commands::Apply.new(args, OpenStruct.new).run!
              rescue
              end
            end

            sleep(5)
          end
        ensure
          File.delete(pidfile) if File.file?(pidfile)
        end
      end
    end
  end
end
