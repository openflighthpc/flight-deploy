require 'open3'
require 'logger'
require 'flight/subprocess'

require_relative './config'

module Profile
  class HunterCLI
    class << self
      def list_nodes
        args = [
          "list-parsed"
        ]
        cmd = new(*flight_hunter, *args)
        cmd.run.tap do |result|
          if result.success?
            return result.stdout
          else
            puts "ERROR"
          end
        end
      end

      private

      def flight_hunter
        if !Config.hunter_command
          raise "Hunter command is not defined"
        end
        Config.hunter_command
      end
    end

    def initialize(*cmd, user: nil, stdin: nil, timeout: 30, env: {})
      @timeout = timeout
      @cmd = cmd
      @user = user
      @stdin = stdin
      @env = {
        'PATH' => Config.command_path,
      }.merge(env)
    end

    def run(&block)
      process = Flight::Subprocess::Local.new(
        env: @env,
        logger: Logger.new(File.join(Config.log_dir,'hunter')),
        timeout: @timeout,
      )
      result = process.run(@cmd, @stdin, &block)
      parse_result(result)
      result
    end

    private

    def parse_result(result)
      if result.exitstatus == 0 && expect_json_response?
        begin
          unless result.stdout.nil? || result.stdout.strip == ''
            result.stdout = JSON.parse(result.stdout)
          end
        rescue JSON::ParserError
          result.exitstatus = 128
        end
      end
    end

    def expect_json_response?
      @cmd.any? { |i| i.strip == '--json' }
    end
  end
end
