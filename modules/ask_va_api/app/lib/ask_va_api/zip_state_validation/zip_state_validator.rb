# frozen_string_literal: true

module AskVAApi
  class ZipStateValidator
    ZIP_NOT_FOUND = 'Zip Code not found'
    STATE_NOT_FOUND = 'State not found'
    ZIP_STATE_MISMATCH = 'Zip/State mismatch'
    INVALID_ZIP = 'Invalid Zip Code'

    class << self
      def call(zipcode:, state_name:)
        zip = normalize_zip(zipcode)
        return invalid_zip_result(zipcode) unless zip

        state_code = state_code_from_name(state_name)
        return state_not_found_result(state_name) unless state_code

        std_state = StdState.find_by(postal_name: state_code)
        return state_not_found_result(state_name) unless std_state

        std_zipcode = StdZipcode.find_by(zip_code: zip)
        return zip_not_found_result(zipcode) unless std_zipcode

        validate_match(std_zipcode:, std_state:, zipcode:, state_code:)
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

      def invalid_zip_result(zipcode)
        ZipStateValidationResult.new(
          valid: false,
          error_code: INVALID_ZIP + ": #{zipcode}",
          error_message: 'Check Zip Code format.'
        )
      end

      def state_not_found_result(state_name)
        ZipStateValidationResult.new(
          valid: false,
          error_code: STATE_NOT_FOUND + ": #{state_name}",
          error_message: 'Check State format.'
        )
      end

      def zip_not_found_result(zipcode)
        ZipStateValidationResult.new(
          valid: false,
          error_code: ZIP_NOT_FOUND + ": #{zipcode}",
          error_message: 'Check Zip Code format.'
        )
      end

      def validate_match(std_zipcode:, std_state:, zipcode:, state_code:)
        if std_zipcode.state_id == std_state.id
          ZipStateValidationResult.new(valid: true)
        else
          ZipStateValidationResult.new(
            valid: false,
            error_code: ZIP_STATE_MISMATCH,
            error_message: "Zip code #{zipcode} does not belong to state #{state_code}."
          )
        end
      end
    end
  end
end
