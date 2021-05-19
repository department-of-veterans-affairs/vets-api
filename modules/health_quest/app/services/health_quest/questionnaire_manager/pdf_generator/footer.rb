# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    module PdfGenerator
      #
      # Object for defining the PDF footer layout
      #
      class Footer
        FOOTER_DATE_FORMAT = '%m/%d/%Y'

        attr_reader :opts, :composer

        ##
        # A method to create an instance of {HealthQuest::QuestionnaireManager::PdfGenerator::Footer}
        # @return [HealthQuest::QuestionnaireManager::PdfGenerator::Footer]
        #
        def self.build(args = {})
          new(args)
        end

        def initialize(args)
          @opts = args[:opts]
          @composer = args[:composer]
        end

        def draw
          composer.bounding_box([0, composer.bounds.bottom + 24], width: composer.bounds.width, height: 24) do
            composer.stroke_bounds
            composer.text_box(
              footer_text,
              at: [0, 24],
              height: 9,
              width: composer.bounds.width,
              size: 9,
              style: :normal,
              align: :center
            )
          end
        end

        def footer_text
          "#{full_name} | Date of birth: #{date_of_birth}"
        end

        def full_name
          "#{user_data['first_name']&.downcase&.capitalize} #{user_data['last_name']&.downcase&.capitalize}"
        end

        def date_of_birth
          DateTime.parse(user_data['date_of_birth']).strftime(FOOTER_DATE_FORMAT)
        end

        def user_data
          @user_data ||= opts[:questionnaire_response]&.user_demographics_data
        end
      end
    end
  end
end
