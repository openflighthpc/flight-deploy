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

    def self.contains?(name)
      Queue.contains?(name)
    end

    private

    # Not to be confused with Thread::Queue
    class Queue
      class << self
        def push(name, identity)
          File.open(File.join(Config.queue_dir, name, 'w') do |file|
            file.write(identity)
          end
        end

        def pop(*names)
          names.each do |name|
            next unless contains?(name)
            File.delete(File.join(Config.queue_dir, name)) }
          end
        end

        def contains?(name)
          File.exists?(File.join(Config.queue_dir, name))
        end

        def index
          Dir[File.join(Config.queue_dir, '*')].map do |f|
            { name: File.basename(f), name: File.read(f) }
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
          File.write(pidfile, pid, 'w')

          until Queue.index.empty?
            grouped = Queue.index.group_by { |n| n[:identity] }
            grouped.each do |group, nodes|
              names = nodes.map { |n| n[:name] }

              Queue.pop(names)

              args = [
                names.join(','),
                group
              ]

              Commands::Apply.new(args, OpenStruct.new).run!
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
