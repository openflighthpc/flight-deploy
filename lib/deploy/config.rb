require 'fileutils'
require 'pathname'
require 'yaml'
require 'shash'

module Deploy
  class Config
    class << self

      # Loads in config file as a hash
      # Convert to super hash so any YAML keys in the file
      # can be accessed like a regular method
      def config
        @config ||= YAML.load_file(Pathname.new('../../etc/config.yml').expand_path(__dir__))
                        .to_shash
      rescue NoMethodError
        raise "Config file has missing values"
      end

      def root
        @root ||= File.expand_path('../..', __dir__)
      end

      def inventory_dir
        raise "Inventory directory not set in config" if !config.inventory_dir
        File.join(root, config.inventory_dir)
      end

      def ansible_dir
        raise "Ansible directory not set in config" if !config.ansible_dir
        config.ansible_dir
      end

      def log_dir
        File.join(root, "log/")
      end
    end
  end
end
