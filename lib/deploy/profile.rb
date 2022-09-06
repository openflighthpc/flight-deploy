module Deploy
  class Profile
    def self.all(cluster_type=nil)
      raise "No cluster type given" unless cluster_type
      raise "Invalid cluster type" unless Type.find(cluster_type)
      @all_profiles ||= [].tap do |a|
        Dir["#{Config.types_dir}/#{cluster_type}/profiles/*.yaml"].each do |file|
          begin
            profile = YAML.load_file(file)
            a << new(
              name: profile['name'],
              description: profile['description'],
              group_name: profile['group_name'],
              command: profile['command']
            )
          rescue NoMethodError
            puts "Error loading #{file}"
          end
        end
      end.sort_by { |n| n.name }
    end

    def self.find(name=nil, cluster_type=nil)
      all(cluster_type).find { |profile| profile.name == name }
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
