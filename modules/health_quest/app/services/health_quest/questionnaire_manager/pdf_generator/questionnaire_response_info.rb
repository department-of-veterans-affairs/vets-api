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
        #
        # @param args [Hash]
        # @return [HealthQuest::QuestionnaireManager::PdfGenerator::QuestionnaireResponseInfo]
        #
        def self.build(args = {})
          new(args)
        end

        def initialize(args)
          @opts = args[:opts]
          @composer = args[:composer]
        end

        ##
        # A pipeline method for determining the layout and
        # generating the QR info section for the Patient's QR
        #
        # @return [String]
        #
        def draw
          visit_header
          questionnaire_items
        end

        ##
        # Set the QR response section header
        #
        # @return [String]
        #
        def visit_header
          composer.text_box 'Prepare for your visit', at: [30, composer.bounds.top - 405], size: 16, style: :bold
        end

        ##
        # Set the QR response section questions and answers
        #
        # @return [String]
        #
        def questionnaire_items
          questions = opts[:questionnaire_response]&.questionnaire_response_data&.fetch('item')

          composer.move_down(composer.bounds.top - 120)

          questions.each do |q|
            answers = q['answer']

            composer.table([[q['text'], '']], table_question_style)
            composer.move_down(16)

            answers.each do |a|
              composer.table([['', a['valueString']]], table_answer_style)
              composer.move_down(10)
            end
          end
        end

        ##
        # Styling info for the questions table
        #
        # @return [Hash]
        #
        def table_question_style
          {
            column_widths: { 0 => 460 },
            cell_style: {
              border_width: 0,
              size: 12,
              align: :left,
              font_style: :bold,
              padding: [0, 0, 0, 45]
            },
            header: true
          }
        end

        ##
        # Styling info for the answers section of the questions table
        #
        # @return [Hash]
        #
        def table_answer_style
          {
            cell_style: {
              border_width: 0,
              size: 12,
              align: :left,
              padding: [0, 0, 0, 35]
            },
            header: true
          }
        end
      end
    end
  end
end
