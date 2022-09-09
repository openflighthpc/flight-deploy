module Profile
  class Identity
    def self.all(cluster_type=nil)
      raise "No cluster type given" unless cluster_type
      raise "Invalid cluster type" unless Type.find(cluster_type)
      @all_identities ||= [].tap do |a|
        Dir["#{Config.types_dir}/#{cluster_type}/identities/*.yaml"].each do |file|
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

    attr_reader :name, :command, :description, :group_name

    def initialize(name:, command:, description:, group_name:)
      @name = name
      @command = command
      @description = description
      @group_name = group_name
    end
  end
end
