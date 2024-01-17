require 'open3'

module Profile
  class ProcessSpawner
    class << self
      def run(commands, log_files: [], wait: false, env: {})
        r, w = IO.pipe
        Process.fork do
          Process.daemon unless wait
          w.puts Process.pid

          # Ansible appends to logfiles, so we delete the old ones.
          # We may want to change this to an archival/log rotation process
          # in the future, but for now I don't think it really matters.
          log_files.each do |file|
            File.delete(File.readlink(file)) if File.file?(file)
          end

          with_clean_env do
            last_exit = commands.each_with_index do |command, idx|
              cmd = expand_env(command['command'], env).squeeze('/')
              # We need to initialize the logfiles before Ansible does, so that
              # we can put our DSL lines in.
              log_files.each do |file|
                File.write(
                  file,
                  "PROFILE_COMMAND #{command["name"]}: #{cmd}\n",
                  mode: 'a'
                )
              end

              process_path = File.join(Config.log_dir, "process-#{Time.now.to_i}.log")
              process_log = File.open(process_path, 'a')
              exit_status = nil
              Open3.popen3(env, command['command']) do |_stdin, stdout, stderr, wait_thr|
                process_log.write(stdout.read)
                process_log.write(stderr.read)
                exit_status = wait_thr.value.exitstatus
              end
              process_log.close

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

      def expand_env(str, env)
        Open3.capture2(env, "echo #{str}")[0].chomp
      end

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
