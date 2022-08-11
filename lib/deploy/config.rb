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
      end

      def root
        @root ||= File.expand_path('../..', __dir__)
      end

      def inventory_dir
        File.join(root, config.inventory_dir)
      end

      def ansible_path
        config.ansible_path
      end

      def log_dir
        File.join(root, "log/")
      end
    end
  end
end
