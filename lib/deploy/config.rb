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
        @config ||= config_hash.to_shash
      rescue NoMethodError
        raise "Config file has missing values"
      end

      def config_hash
        @config_hash ||= YAML.load_file(config_path) || {}
      end

      def append_to_config(details_to_append)
        details_to_append.each do |key,value|
          config_hash[key] = value
        end
        File.write(config_path, YAML.dump(config_hash))
      end

      def config_path
        Pathname.new('../../etc/config.yml').expand_path(__dir__)
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

      def questions
        config.configuration_questions
      end
    end
  end
end
