module Profile
  class QueueManager
    def self.push(name, identity)
      Queue.push(name, identity)

      return if QueueMonitor.running?

      # Fork process and daemonise it so that parent process can continue
      Process.fork do
        Process.daemon
        QueueMonitor.start
      end
    end

    def self.pop(name)
      Queue.pop(name)
    end

    def self.contains?(name)
      Queue.contains?(name)
    end

    def self.identity(name)
      Queue.index[name.to_sym][:identity]
    end
  end

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
        File.file?(node_file(name))
      end

      def index
        Dir[node_file('*')].map { |f| [File.basename(f), File.read(f)] }.to_h
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
          grouped = Queue.index.group_by { |k,v| v }
          grouped.each do |group, nodes|
            names = nodes.map(&:last)

            Queue.pop(names)

            args = [
              names.join(','),
              group
            ]

            begin
              Commands::Apply.new(args, OpenStruct.new).run!
            rescue => e
              puts e
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
