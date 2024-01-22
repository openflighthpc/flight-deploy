# frozen_string_literal: true

require 'fileutils'
require 'shash'
require 'open3'

require_relative './config'

module Profile
  class Type
    def self.all
      @all_types ||= [].tap do |a|
        Config.type_paths.each do |p|
          Dir["#{p}/*/"].each do |dir|
            metadata_file = File.join(dir, 'metadata.yaml')
            next unless File.file?(metadata_file)

            type = YAML.load_file(metadata_file)

            state_file = File.join(dir, 'state.yaml')
            state = case File.file?(state_file)
                    when true
                      state = YAML.load_file(state_file)['prepared']
                    when false
                      false
                    end

            a << new(
              id: type['id'],
              name: type['name'],
              description: type['description'],
              questions: type['questions'],
              prepared: state,
              base_path: dir
            )
          end
        end

        a.each do |t|
          if (a - [t]).any? { |u| u.id == t.id }
            raise "Duplicate types exist across type paths; please remove all duplicate instances of: #{t.id}"
          end
        end
      end.sort_by(&:name)
    end

    def self.[](name)
      all.find { |type| type.name == name || type.id == name }
    end

    def self.find(*names)
      self[names.compact.first { |name| self[name] }]
    end

    def fetch_answer(id)
      answers[id]
    end

    def save_answers(answers_hash)
      new_answers = answers.merge(answers_hash)
      File.write(answers_file, YAML.dump(new_answers))
      File.chmod(0o600, answers_file)
    end

    def answers
      @answers ||= YAML.load_file(answers_file)
    rescue Errno::ENOENT
      {}
    end

    def answers_file
      File.join(Config.answers_dir, "#{id}.yaml")
    end

    def valid_answers(qs = questions, parent_answer = nil)
      {}.tap do |as|
        qs.each do |q|
          next unless parent_answer.nil? || parent_answer == q.where
          as[q.id] = answers[q.id] unless answers[q.id].nil?
          next unless q.questions
          child_as = valid_answers(q.questions, answers[q.id])
          as.merge!(child_as);
        end
      end
    end

    def prepared?
      !!prepared
    end

    def verify
      File.write(File.join(base_path, 'state.yaml'), { 'prepared' => true }.to_yaml)
    end

    def identities
      Identity.all(id)
    end

    def find_identity(name)
      identities.find { |identity| identity.name == name }
    end

    def questions
      @questions.map(&:to_shash)
    end

    def recursive_questions(qs = self.questions)
      [].tap do |collection|
        qs.each do |q|
          collection << q
          collection.concat(recursive_questions(q.questions)) if q.questions
        end
      end
    end

    def prepare
      raise "No script found for preparing the #{name} cluster type" unless File.exist?(prepare_command)

      log_name = "#{Config.log_dir}/#{id}-#{Time.now.to_i}.log"

      Open3.popen2e(
        "bash -e #{prepare_command}",
        chdir: run_env
      ) do |_stdin, stdout_stderr, wait_thr|
        Thread.new do
          stdout_stderr.each do |l|
            File.open(log_name, 'a+') { |f| f.write l }
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

    def initialize(id:, name:, description:, questions:, base_path:, prepared:)
      @id = id
      @name = name
      @description = description
      @questions = questions
      @base_path = base_path
      @prepared = prepared
    end

    private

    attr_reader :prepared
  end
end
