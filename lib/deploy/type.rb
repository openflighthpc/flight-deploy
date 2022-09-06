require 'shash'

module Deploy
  class Type
    def self.all
      @all_types ||= [].tap do |a|
        Dir["#{Config.types_dir}/*/metadata.yaml"].each do |file|
          begin
            type = YAML.load_file(file)
            a << new(
              id: type['id'],
              name: type['name'],
              description: type['description'],
              questions: type['questions'],
            )
          rescue NoMethodError
            puts "Error loading #{file}"
          end
        end
      end.sort_by { |n| n.name }
    end

    def self.find(name=nil)
      all.find { |type| type.name == name || type.id == name }
    end

    def profiles
      Profile.all(id)
    end

    def find_profile(name=nil)
      profiles.find { |profile| profile.name == name }
    end

    def questions
      @questions.map { |q| q.to_shash }
    end

    attr_reader :id, :name, :description

    def initialize(id:, name:, description:, questions:)
      @id = id
      @name = name
      @description = description
      @questions = questions
    end
  end
end
