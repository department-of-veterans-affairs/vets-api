# frozen_string_literal: true

require 'mms/data_formatting'

module SurvivorsBenefits
  module StructuredData
    class StructuredDataService
      include Mms::DataFormatting
      include SurvivorsBenefits::StructuredData::Section01
      include SurvivorsBenefits::StructuredData::Section02
      include SurvivorsBenefits::StructuredData::Section03
      include SurvivorsBenefits::StructuredData::Section04
      include SurvivorsBenefits::StructuredData::Section05
      include SurvivorsBenefits::StructuredData::Section06
      include SurvivorsBenefits::StructuredData::Section07
      include SurvivorsBenefits::StructuredData::Section08
      include SurvivorsBenefits::StructuredData::Section09
      include SurvivorsBenefits::StructuredData::Section10
      include SurvivorsBenefits::StructuredData::Section11
      include SurvivorsBenefits::StructuredData::Section12

      attr_reader :form
      attr_accessor :fields

      FIELDS_PATH = Rails.root.join(
        'modules',
        'survivors_benefits',
        'app',
        'services',
        'survivors_benefits',
        'structured_data',
        'fields.yaml'
      ).freeze

      def initialize(form)
        @form = form
        @fields = YAML.load_file(FIELDS_PATH)
      end

      def build_structured_data
        build_section1
        build_section2
        build_section3
        build_section4
        build_section5
        build_section6
        build_section7
        build_section8
        build_section9
        build_section10
        build_section11(form['bankAccount'])
        build_section12

        fields
      end

      ##
      # Build the name fields from the form data.
      # used by Section01 and Section02
      # @param name [Hash]
      # @param individual [String] - The prefix for the field keys (e.g., "VETERAN", "CLAIMANT")
      def merge_name_fields(name, individual)
        if name && %w[VETERAN CLAIMANT].include?(individual)
          name = build_name(name)
          fields.merge!(
            {
              "#{individual}_NAME" => name[:full],
              "#{individual}_FIRST_NAME" => name[:first],
              "#{individual}_MIDDLE_INITIAL" => name[:middle_initial],
              "#{individual}_LAST_NAME" => name[:last]
            }
          )
        end
      end
    end
  end
end
