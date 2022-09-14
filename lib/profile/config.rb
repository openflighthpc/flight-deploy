require 'fileutils'
require 'pathname'
require 'yaml'
require 'shash'

module Profile
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

      def cluster_type
        config.cluster_type
      end

      def config_hash
        @config_hash ||= File.exists?(config_path) ? (YAML.load_file(config_path) || {}) : {}
      end

      def append_to_config(details_to_append)
        details_to_append.each do |key,value|
          config_hash[key] = value
        end
        File.write(config_path, YAML.dump(config_hash))
      end

      def fetch(*keys)
        values = keys.map do |key|
          config.public_send(key.to_sym)
        end
        values.length > 1 ? values : values.first
      end

      def root
        @root ||= File.expand_path('../..', __dir__)
      end

      def config_path
        File.join(root, "etc/config.yml")
      end

      def inventory_dir
        File.join(root, "var", "inventory")
      end

      def log_dir
        File.join(root, "log/")
      end

      def ansible_inv_dir
        File.join(root, "var", "ansible_invs")
      end

      def type_paths
        (config.type_paths || [File.join(root, "etc/types")])
      end
    end
  end
end
