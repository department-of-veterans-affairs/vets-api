# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    module PdfGenerator
      #
      # Object for defining the PDF header layout
      #
      class Header
        HEADER_DATE_FORMAT = '%m/%d/%Y'
        VA_LOGO = 'modules/health_quest/app/assets/images/va_logo.png'
        VA_URL = 'https://va.gov/'

        attr_reader :opts, :composer

        ##
        # A method to create an instance of {HealthQuest::QuestionnaireManager::PdfGenerator::Header}
        # @return [HealthQuest::QuestionnaireManager::PdfGenerator::Header]
        #
        def self.build(args = {})
          new(args)
        end

        def initialize(args)
          @opts = args[:opts]
          @composer = args[:composer]
        end

        def draw
          composer.bounding_box([0, composer.bounds.top], width: composer.bounds.width, height: 148) do
            composer.stroke_bounds
            composer.text_box today, at: [20, 128], height: 9, width: 150, size: 9, style: :normal
            composer.text_box VA_URL, at: [525, 128], height: 9, width: 150, size: 9, style: :normal
            composer.image VA_LOGO, scale: 0.25, padding: 0, at: [18, 118]
            composer.text_box qr_data.dig('questionnaire', 'title'), at: [20, 62], size: 20, style: :bold
            composer.text_box org_name, at: [20, 28], size: 12, style: :normal
          end
        end

        def qr_data
          @qr_data ||= opts[:questionnaire_response]&.questionnaire_response_data
        end

        def org_name
          @org_name ||= opts[:org]&.resource&.name
        end

        def today
          DateTime.now.to_date.strftime(HEADER_DATE_FORMAT)
        end
      end
    end
  end
end
