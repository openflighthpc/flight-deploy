require 'fileutils'
require 'pathname'
require 'yaml'
require 'xdg'
require 'tty-config'

module Profile
  class Config
    class << self
      PROFILE_DIR_SUFFIX = File.join('flight', 'profile')

      def data
        @data ||= TTY::Config.new.tap do |cfg|
          cfg.append_path(config_path)
          begin
            cfg.read
          rescue TTY::Config::ReadError
            nil
          end
        end
      end

      def cluster_type
        data.fetch(:cluster_type)
      end

      def use_hunter?
        data.fetch(:use_hunter) || false
      end

      def type_paths
        data.fetch(:type_paths) || [File.join(root, "etc/types")]
      end

      def log_dir
        data.fetch(:log_dir) || dir_constructor(root, 'var', 'log')
      end

      def shared_secret
        return unless File.file?(shared_secret_path)
        File.read(shared_secret_path)
      end

      def shared_secret_path
        ENV['flight_HUNTER_shared_secret_path'] ||
        data.fetch(:shared_secret_path)
      end

      def hunter_command
        command = 
          ENV['flight_PROFILE_hunter_command'] ||
            data.fetch(:hunter_command) ||
            File.join(ENV.fetch('flight_ROOT', '/opt/flight/'), 'bin/flight hunter')
        if !File.file?(File.join(command.split[0]))
          raise "Could not find '#{command.split[0]}'"
        elsif !File.executable?(File.join(command.split[0]))
          raise "#{command.split[0]} is not executable"
        end
        command.split(' ')
      end

      def command_path
        ENV['PATH']
      end

      def inventory_dir
        dir_constructor(root, "var", "inventory")
      end

      def ansible_inv_dir
        dir_constructor(root, "var", "ansible_invs")
      end

      def answers_dir
        dir_constructor(root, 'var', 'answers/')
      end

      def queue_dir
        dir_constructor(root, 'var', 'queue')
      end

      def save_data
        FileUtils.mkdir_p(config_path)
        data.write(force: true)
      end

      def root
        @root ||= File.expand_path(File.join(__dir__, '..', '..'))
      end

      def config_path
        @config_path = File.join(root, 'etc')
      end

      def ansible_callback_dir
        File.join(Config.root, 'opt', 'ansible_callbacks')
      end

      private

      def dir_constructor(*a)
        dir = File.join(*a) 
        FileUtils.mkdir_p(dir).first
      end

      def xdg_config
        @xdg_config ||= XDG::Config.new
      end

      def xdg_data
        @xdg_data ||= XDG::Data.new
      end

      def xdg_cache
        @xdg_cache ||= XDG::Cache.new
      end
    end
  end
end
