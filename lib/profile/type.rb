require 'shash'

module Profile
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

    def self.find(name)
      all.find { |type| type.name == name || type.id == name }
    end

    def identities
      Identity.all(id)
    end

    def find_identity(name)
      identities.find { |identity| identity.name == name }
    end

    def questions
      @questions.map { |q| q.to_shash }
    end

    def prepare
      raise "No script found for preparing the #{name} cluster type" unless File.exists?(prepare_command)
      log_name = "#{Config.log_dir}/#{id}-#{Time.now.to_i}.log"
      pid = Process.spawn(
        { "DEPLOYDIR" => Config.root },
        prepare_command,
        [:out, :err] => log_name
      )
      Process.wait(pid)
    end

    def prepare_command
      File.join(Config.types_dir, id, 'prepare.sh')
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
