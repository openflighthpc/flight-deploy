require 'fileutils'
require 'shash'
require 'open3'

module Profile
  class Type
    def self.all
      @all_types ||= [].tap do |a|
        Config.type_paths.each do |p|
          Dir["#{p}/*/"].each do |dir|
            begin
              type = YAML.load_file(File.join(dir, "metadata.yaml"))

              a << new(
                id: type['id'],
                name: type['name'],
                description: type['description'],
                questions: type['questions'],
                base_path: dir
              )
            rescue NoMethodError
              puts "Error loading #{file}"
            end
          end
        end

        a.each do |t|
          if (a - [t]).any? { |u| u.id == t.id }
            raise "Duplicate types exist across type paths; please remove all duplicate instances of: #{t.id}"
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

      Open3.popen2e(
        prepare_command,
        chdir: run_env
      )  do |stdin, stdout_stderr, wait_thr|
        Thread.new do
          stdout_stderr.each do |l|
            File.open(log_name, "a+") { |f| f.write l}
          end
        end
        wait_thr.value
      end
    end

    def prepare_command
      File.join(base_path, 'prepare.sh')
    end

    def run_env
      FileUtils.mkdir_p(File.join(base_path, 'run_env/')).first
    end

    attr_reader :id, :name, :description, :base_path

    def initialize(id:, name:, description:, questions:, base_path:)
      @id = id
      @name = name
      @description = description
      @questions = questions
      @base_path = base_path
    end
  end
end
