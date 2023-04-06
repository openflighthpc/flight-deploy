module Profile
  class ProcessSpawner
    class << self

      def run(commands, log_file: nil, env: {})
        Process.fork do
          with_clean_env do
            last_exit = commands.each do |command|
              sub_pid = Process.spawn(
                env,
                "echo PROFILE_COMMAND #{command[:name]}: #{command[:value]}; #{command[:value]}",
                [:out, :err] => [log_name, "a+"]
              )

              Process.wait(sub_pid)
              exit_status = $?.exitstatus

              if exit_status != 0 || command ==  cmd.last
                break exit_status
              end
            end

            yield last_exit if block_given?
          end
        end
      end
      
      private

      def with_clean_env(&block)
        if Kernel.const_defined?(:OpenFlight) && OpenFlight.respond_to?(:with_standard_env)
          Openflight.with_standard_env { block.call }
        else
          msg = Bundler.respond_to?(:with_unbundled_env) ? :with_unbundled_env : :with_clean_env
          Bundler.__send__(msg) { block.call }
        end
      end
    end
  end
end
