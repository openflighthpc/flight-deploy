module Profile
  class ProcessSpawner
    class << self
      def run(commands, log_file: nil, wait: false, env: {})
        r, w = IO.pipe
        Process.fork do
          Process.daemon unless wait
          w.puts Process.pid
          with_clean_env do
            last_exit = commands.each_with_index do |command, idx|
              sub_pid = Process.spawn(
                env,
                "echo PROFILE_COMMAND #{command["name"]}: #{command["command"]}; #{command["command"]}",
                [:out, :err] => [log_file, "a+"]
              )

              Process.wait(sub_pid)
              exit_status = $?.exitstatus

              if exit_status != 0 || idx == commands.size - 1
                break exit_status
              end
            end

            yield last_exit if block_given?
          end
        end

        r.gets.chomp
      end
      
      private

      def with_clean_env(&block)
        if Kernel.const_defined?(:OpenFlight) && OpenFlight.respond_to?(:with_standard_env)
          OpenFlight.with_standard_env { block.call }
        else
          msg = Bundler.respond_to?(:with_unbundled_env) ? :with_unbundled_env : :with_clean_env
          Bundler.__send__(msg) { block.call }
        end
      end
    end
  end
end
