# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    module PdfGenerator
      #
      # Object for defining the basic appointment body
      #
      # @!attribute opts
      #   @return [Hash]
      # @!attribute composer
      #   @return [HealthQuest::QuestionnaireManager::PdfGenerator::Composer]
      class QuestionnaireResponseInfo
        attr_reader :opts, :composer

        ##
        # A method to create an instance of {HealthQuest::QuestionnaireManager::PdfGenerator::QuestionnaireResponseInfo}
        # @return [HealthQuest::QuestionnaireManager::PdfGenerator::QuestionnaireResponseInfo]
        #
        def self.build(args = {})
          new(args)
        end

        def initialize(args)
          @opts = args[:opts]
          @composer = args[:composer]
        end

        def draw
          visit_header
          questionnaire_items
        end

        def visit_header
          composer.text_box 'Prepare for your visit', at: [30, composer.bounds.top - 405], size: 16, style: :bold
        end

        def questionnaire_items
          questions = opts[:questionnaire_response]&.questionnaire_response_data&.fetch('item')

          composer.bounding_box([0, composer.bounds.top - 445], width: composer.bounds.width - 20) do
            questions.each_with_index do |q, index|
              # answers = q['answer']

              composer.text_box q['text'], at: [30, -(index * 60)], size: 12, style: :bold

              # answers.each do |a|
              #   composer.text_box a['valueString'], at: [90, composer.bounds.top - 475], size: 12
              # end
            end
          end
        end
      end
    end
  end
end
