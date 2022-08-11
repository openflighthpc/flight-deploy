module Deploy
  class Node
    def self.all
      @all_nodes ||= [].tap do |a|
        Dir["#{Config.inventory_dir}/*.yaml"].each do |file|
          node = YAML.load_file(file)
          a << new(
            hostname: node['hostname'],
            profile: node['profile'],
            status: node['status']
          )
        end
      end.sort_by { |n| n.hostname }
    end

    attr_reader :hostname, :profile, :status

    def initialize(hostname:, profile:, status:)
      @hostname = hostname
      @profile = profile
      @status = status
    end
  end
end
