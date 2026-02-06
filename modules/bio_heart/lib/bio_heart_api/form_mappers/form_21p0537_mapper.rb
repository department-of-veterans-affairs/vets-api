# frozen_string_literal: true

require 'bio_heart_api/form_mappers/base_mapper'

module BioHeartApi
  module FormMappers
    class Form21p0537Mapper < BioHeartApi::FormMappers::BaseMapper
      FORM_TYPE = '21P-0537'

      def call
        form = @params.to_h.with_indifferent_access

        # Build the IBM payload according to the data dictionary
        {
          # 1A - Have you remarried since the death of the veteran?
          'REMARRIED_AFTER_VET_DEATH_YES' => remarried_yes?(form),
          'REMARRIED_AFTER_VET_DEATH_NO' => remarried_no?(form),

          # 1B - Date of Marriage
          'DATE_OF_MARRIAGE' => parse_date(form.dig('remarriage', 'date_of_marriage')),

          # 1C - Name of Spouse (VETERAN_FULL_NAME maps to VETERAN_NAME in output)
          'VETERAN_NAME' => build_spouse_full_name(form),
          'SPOUSE_FIRST_NAME' => form.dig('remarriage', 'spouse_name', 'first'),
          'SPOUSE_MIDDLE_INITIAL' => extract_middle_initial(form.dig('remarriage', 'spouse_name')),
          'SPOUSE_LAST_NAME' => form.dig('remarriage', 'spouse_name', 'last'),

          # 1E - Is your spouse a Veteran?
          'SPOUSE_VET_YES' => spouse_veteran_yes?(form),
          'SPOUSE_VET_NO' => spouse_veteran_no?(form),

          # 1F - VA Claim Number or SSN
          'VA_CLAIM_NUMBER' => form.dig('remarriage', 'spouse_va_file_number').presence,
          'SSN' => format_ssn(form.dig('remarriage', 'spouse_ssn')),

          # 5A - Signature
          'SIGNATURE' => form.dig('recipient', 'signature'),

          # 5B - Date Signed
          'DATE_SIGNED' => parse_date(form.dig('recipient', 'signature_date')),

          # Form Type (must be prefixed with StructuredData: to be ingested)
          'FORM_TYPE' => "StructuredData:#{FORM_TYPE}"
        }.compact
      end

      private

      # Determine if remarried YES checkbox should be checked
      #
      # @param form [Hash] The form data
      # @return [String, nil] true if remarried, nil otherwise
      def remarried_yes?(form)
        form['has_remarried'] == true ? true : nil
      end

      # Determine if remarried NO checkbox should be checked
      #
      # @param form [Hash] The form data
      # @return [String, nil] true if not remarried, nil otherwise
      def remarried_no?(form)
        form['has_remarried'] == false ? true : nil
      end

      # Determine if spouse veteran YES checkbox should be checked
      #
      # @param form [Hash] The form data
      # @return [String, nil] true if spouse is veteran, nil otherwise
      def spouse_veteran_yes?(form)
        form.dig('remarriage', 'spouse_is_veteran') == true ? true : nil
      end

      # Determine if spouse veteran NO checkbox should be checked
      #
      # @param form [Hash] The form data
      # @return [String, nil] true if spouse is not veteran, nil otherwise
      def spouse_veteran_no?(form)
        form.dig('remarriage', 'spouse_is_veteran') == false ? true : nil
      end

      # Build spouse full name from name hash
      #
      # @param form [Hash] The form data
      # @return [String, nil] Full spouse name or nil
      def build_spouse_full_name(form)
        build_full_name(form.dig('remarriage', 'spouse_name'))
      end
    end
  end
end
