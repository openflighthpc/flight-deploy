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
              dependencies: metadata['dependencies'],
              conflicts: metadata['conflicts'],
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

    def self.set_conditional_dependencies(cluster_type, identity, dependencies)
      metadata_path = File.join(cluster_type.base_path, "identities", identity, 'metadata.yaml')
      metadata = YAML.load_file(metadata_path)
      metadata['conditional_dependencies'] = dependencies
      File.write(metadata_path, metadata.to_yaml)
    end

    def removable?
      !!commands['remove']
    end

    attr_reader :name, :commands, :description, :group_name, :dependencies, :conflicts

    def initialize(name:, commands:, description:, group_name:, dependencies:, conflicts:)
      @name = name
      @commands = commands
      @description = description
      @group_name = group_name
      @dependencies = dependencies || []
      @conflicts = conflicts || []
    end
  end
end
