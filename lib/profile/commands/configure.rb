require 'tty-prompt'
require 'yaml'
require_relative '../command'
require_relative '../type'

module Profile
  module Commands
    class Configure < Command
      def run
        if @options.show
          display_details
        else
          ask_questions
          save_answers
        end
      end

      private

      def display_details
        raise "Cluster has not yet been configured - please run `configure`" unless Config.cluster_type
        type = Type.find(Config.cluster_type)
        raise "Invalid cluster type has been saved - please rerun `configure`" unless type

        puts "Cluster type: #{type.name}"
        type.questions.each do |question|
          puts "#{question.text} #{ Config.fetch(question.id) || 'none' }"
        end
      end

      def ask_questions
        type = cluster_type
        @answers = prompt.collect do
          Type.find(type).questions.each do |question|
            key(question.id).ask(question.text) do |q|
              if Config.fetch(question.id)
                q.default Config.fetch(question.id)
              elsif question.default
                q.default question.default
              end
              q.required question.validation.required
              if question.validation.to_h.key?(:format)
                q.validate Regexp.new(question.validation.format)
                q.messages[:valid?] = question.validation.message
              end
            end
          end
        end
      end

      def prompt
        @prompt ||= TTY::Prompt.new(help_color: :yellow)
      end

      def cluster_type
        @type ||= Type.find( prompt.select('Cluster type: ', Type.all.map { |t| t.name }) )
                      .id
      end

      def save_answers
        raise 'Attempted to save answers without answering questions' unless @answers
        Config.append_to_config({ 'cluster_type' => cluster_type }.merge(@answers))
      end
    end
  end
end
