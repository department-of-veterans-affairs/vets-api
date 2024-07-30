# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    module PdfGenerator
      #
      # Object for defining the PDF footer layout
      #
      # @!attribute opts
      #   @return [Hash]
      # @!attribute composer
      #   @return [HealthQuest::QuestionnaireManager::PdfGenerator::Composer]
      class Footer
        FOOTER_DATE_FORMAT = '%m/%d/%Y'

        attr_reader :opts, :composer

        ##
        # A method to create an instance of {HealthQuest::QuestionnaireManager::PdfGenerator::Footer}
        #
        # @param args [Hash]
        # @return [HealthQuest::QuestionnaireManager::PdfGenerator::Footer]
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
        # generating the footer for the Patient's QR
        #
        # @return [String]
        #
        def draw
          composer.bounding_box([0, composer.bounds.bottom + 24], width: composer.bounds.width, height: 24) do
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

        ##
        # The PDF footer text
        #
        # @return [String]
        #
        def footer_text
          "#{full_name} | Date of birth: #{date_of_birth}"
        end

        ##
        # The patient's full name
        #
        # @return [String]
        #
        def full_name
          if user_data
            "#{user_data['first_name']&.downcase&.capitalize} #{user_data['last_name']&.downcase&.capitalize}"
          end
        end

        ##
        # The patient's data of birth
        #
        # @return [String]
        #
        def date_of_birth
          DateTime.parse(user_data['date_of_birth']).strftime(FOOTER_DATE_FORMAT) if user_data
        end

        ##
        # The snapshot of the patient's demographics data
        # when the QR was submitted to the Lighthouse database
        #
        # @return [Hash]
        #
        def user_data
          @user_data ||= opts[:questionnaire_response]&.user_demographics_data
        end
      end
    end
  end
end
