module Deploy
  class Node
    def self.all
      @all_nodes ||= [].tap do |a|
        YAML.load_file(Config.inventory_path)['nodes'].each do |node|
          a << new(
            hostname: node['hostname'],
            profile: node['profile'],
            status: node['status'],
            )
        end
      end
    end

    attr_reader :hostname, :profile, :status

    def initialize(hostname:, profile:, status:)
      @hostname = hostname
      @profile = profile
      @status = status
    end
  end
end
