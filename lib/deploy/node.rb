module Deploy
  class Node
    def self.all
      all_nodes = []
      YAML.load_file(Config.inventory_path)['nodes'].each do |node|
        all_nodes << new(
          hostname: node['hostname'],
          profile: node['profile'],
          status: node['status'],
          )
      end
      all_nodes
    end

    attr_reader :hostname, :profile, :status

    def initialize(hostname:, profile:, status:)
      @hostname = hostname
      @profile = profile
      @status = status
    end
  end
end
