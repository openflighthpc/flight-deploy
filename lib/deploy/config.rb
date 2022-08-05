require 'fileutils'
require 'pathname'
require 'yaml'

module Deploy
  class Config
    class << self

      # Loads in config file as a hash; any YAML keys in the file
      # can be accessed like a regular method.
      def config
        @config ||= YAML.load_file(Pathname.new('../../etc/config.yml').expand_path(__dir__))
      end

      def inventory_path
        config.inventory_path
      end
    end
  end
end
