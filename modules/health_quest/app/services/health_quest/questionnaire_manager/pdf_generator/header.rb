# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    module PdfGenerator
      #
      # Object for defining the PDF header layout
      #
      # @!attribute opts
      #   @return [Hash]
      # @!attribute composer
      #   @return [HealthQuest::QuestionnaireManager::PdfGenerator::Composer]
      class Header
        HEADER_DATE_FORMAT = '%m/%d/%Y'
        VA_LOGO = 'modules/health_quest/app/assets/images/va_logo.png'
        VA_URL = 'https://va.gov/'

        attr_reader :opts, :composer

        ##
        # A method to create an instance of {HealthQuest::QuestionnaireManager::PdfGenerator::Header}
        #
        # @param args [Hash]
        # @return [HealthQuest::QuestionnaireManager::PdfGenerator::Header]
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
        # generating the header for the Patient's QR
        #
        # @return [String]
        #
        def draw
          composer.bounding_box([0, composer.bounds.top], width: composer.bounds.width, height: 178) do
            composer.text_box today, at: [30, 153], height: 9, width: 150, size: 9, style: :normal
            composer.text_box VA_URL, at: [515, 153], height: 9, width: 150, size: 9, style: :normal
            composer.image VA_LOGO, scale: 0.25, padding: 0, at: [28, 128]
            composer.text_box qr_data.dig('questionnaire', 'title'), at: [30, 62], size: 20, style: :bold if qr_data
            composer.text_box org_name, at: [30, 23], size: 12, style: :normal if org_name
          end
        end

        ##
        # The snapshot data of the QR that was successfully
        # submitted to the Lighthouse PGD database
        #
        # @return [Hash]
        #
        def qr_data
          @qr_data ||= opts[:questionnaire_response]&.questionnaire_response_data
        end

        ##
        # The organization name in the Patient's QR
        #
        # @return [String]
        #
        def org_name
          @org_name ||= opts[:org]&.resource&.name
        end

        ##
        # Today's date in the desired format
        #
        # @return [String]
        #
        def today
          DateTime.now.to_date.strftime(HEADER_DATE_FORMAT)
        end
      end
    end
  end
end
