module Profile
  class Identity
    def self.all(cluster_type=nil)
      cluster_type = Type.find(cluster_type) || Type.find(Config.cluster_type)
      raise "Cluster type not found" unless cluster_type

      @all_identities ||= [].tap do |a|
        Dir["#{cluster_type.base_path}/identities/*.yaml"].each do |file|
          begin
            identity = YAML.load_file(file)
            a << new(
              name: identity['name'],
              description: identity['description'],
              group_name: identity['group_name'],
              command: identity['command']
            )
          rescue NoMethodError
            puts "Error loading #{file}"
          end
        end
      end.sort_by { |n| n.name }
    end

    def self.find(name, cluster_type)
      all(cluster_type).find { |ident| ident.name == name }
    end

    attr_reader :name, :command, :description, :group_name

    def initialize(name:, command:, description:, group_name:)
      @name = name
      @command = command
      @description = description
      @group_name = group_name
    end
  end
end
