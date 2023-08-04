
module Profile
  class QueueManager
    def self.push(name, identity, options: {})
      Queue.push(name, identity, options: options)

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
      Queue.index[name][:identity]
    end
  end

  # Not to be confused with Thread::Queue
  class Queue
    class << self
      def node_file(name)
        File.join(Config.queue_dir, name)
      end

      def push(name, identity, options: {})
        File.open(node_file(name), 'w') do |file|
          data = { identity: identity, options: options }.to_json
          file.write(data)
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
        Dir[node_file('*')].map do |f|
          data = JSON.parse(File.read(f))
          {
            File.basename(f) => {
              identity: data['identity'],
              options: data['options']
            }
          }
        end.reduce({}, :merge)
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
            names = nodes.map(&:first)

            Queue.pop(*names)

            args = [
              names.join(','),
              group[:identity]
            ]

            opts = OpenStruct.new(group[:options])

            begin
              Commands::Apply.new(args, opts).run!
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
