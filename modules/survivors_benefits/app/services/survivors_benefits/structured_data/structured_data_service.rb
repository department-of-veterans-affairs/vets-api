# frozen_string_literal: true

module SurvivorsBenefits
  module StructuredData
    class StructuredDataService
      include HasStructuredData
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
        merge_veterans_id_info # Section01
        merge_claimants_id_info # Section02
        merge_veterans_service_info # Section03
        merge_marital_info # Section04
        merge_marital_history # Section05
        merge_children_of_veteran_info # Section06
        merge_dic_info # Section07
        merge_nursing_home_info # Section08
        merge_income_and_assets_info # Section09
        merge_medical_last_burial_expenses # Section10
        merge_claimant_direct_deposit_fields(form['bankAccount']) # Section11
        merge_claim_certification_fields # Section12

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
