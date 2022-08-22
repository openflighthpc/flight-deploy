module Deploy
  class Profile
    def self.all
      @all_profiles ||= [].tap do |a|
        Dir["#{Config.profiles_dir}/*.yaml"].each do |file|
          begin
            profile = YAML.load_file(file)
            a << new(
              name: profile['name'],
              command: profile['command'],
              description: profile['description']
            )
          rescue NoMethodError
            puts "Error loading #{file}"
          end
        end
      end.sort_by { |n| n.name }
    end

    def self.find(name=nil)
      all.find { |profile| profile.name == name }
    end

    def filepath
      File.join(Config.profile_dir, "#{name}.yaml")
    end

    attr_reader :name, :command, :description

    def initialize(name:, command:, description:)
      @name = name
      @command = command
      @description = description
    end
  end
end
