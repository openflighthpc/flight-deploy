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
              commands: identity['commands'],
              priority: identity['priority']
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

    attr_reader :name, :commands, :description, :group_name, :priority

    def initialize(name:, commands:, description:, group_name:, priority:)
      @name = name
      @commands = [].tap do |l|
        commands.each do |cmd|
          l << { name: cmd.keys.first, value: cmd.values.first }
        end
      end
      @description = description
      @group_name = group_name
      @priority = priority
    end
  end
end
