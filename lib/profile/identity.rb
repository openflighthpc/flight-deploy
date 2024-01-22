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
              dependencies: metadata['dependencies'].to_a + conditional_dependencies(cluster_type)[metadata['name']],
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

    def self.conditional_dependencies(cluster_type)
      Hash.new([]).tap do |ds|
        all_questions = cluster_type.recursive_questions
        cluster_type.valid_answers.each do |id, ans|
          question = all_questions.find { |q| q.id == id }
          conditional_dependencies = question.dependencies
          next unless conditional_dependencies
          matched_dependencies = conditional_dependencies.select { |cd| cd.where == ans }
          matched_dependencies.each do |md|
            ds[md.identity].concat(md.depend_on)
          end
        end
      end
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
