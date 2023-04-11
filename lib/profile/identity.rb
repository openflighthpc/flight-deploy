module Profile
  class Identity
    def self.all(cluster_type=nil)
      cluster_type = Type.find(cluster_type) || Type.find(Config.cluster_type)
      raise "Cluster type not found" unless cluster_type

      @all_identities ||= [].tap do |a|
        glob = File.join(cluster_type.base_path, "identities", "*")
        Dir.glob(glob).each do |identity|
          begin
            metadata = YAML.load_file(File.join(identity, "metadata.yaml"))
            cmds = YAML.load_file(File.join(identity, "commands.yaml"))

            a << new(
              name: metadata['name'],
              description: metadata['description'],
              group_name: metadata['group_name'],
              commands: cmds
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

    attr_reader :name, :commands, :description, :group_name

    def initialize(name:, commands:, description:, group_name:)
      @name = name
      @commands = commands
      @description = description
      @group_name = group_name
    end
  end
end
