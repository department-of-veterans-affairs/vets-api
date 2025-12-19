# frozen_string_literal: true

module AskVAApi
  class ZipStateValidator
    ZIP_NOT_FOUND = 'Zip Code not found'
    STATE_NOT_FOUND = 'State not found'
    ZIP_STATE_MISMATCH = 'Zip/State mistmatch'
    IVALID_ZIP = 'Invalid Zip Code'

    class << self
      def call(zipcode:, state_name:)
        zip = normalize_zip(zipcode)
        return invalid_zip_result unless zip

        state_code = state_code_from_name(state_name)
        state_not_found_result unless state_code
      end

      private

      def normalize_zip(zipcode)
        # convert full zip to a 5 digit zip
        basic_zip = zipcode.to_s.strip.split('-').first
        return nil unless basic_zip.match?(/\A\d{5}\z/)

        basic_zip
      end

      # grab the state code for safer lookup when querying the std_state table
      def state_code_from_name(state_name)
        normalized_name = state_name.to_s.strip.downcase
        return nil if normalized_name.empty?

        code_by_lower_name = I18n.t('ask_va_api.states').each_with_object({}) do |(state_code, full_name), acc|
          acc[full_name.to_s.downcase] = state_code.to_s
        end

        code_by_lower_name[normalized_name]
      end

      def ivalid_zip(zipcode)
        ZipStateValidationResult.new(valid: false, error_code: INVALID_ZIP, error_message: 'Check Zip Code format')
      end
    end
  end
end
