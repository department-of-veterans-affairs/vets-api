# frozen_string_literal: true

module AskVAApi
  class ZipStateValidator
    ZIP_STATE_MISMATCH = 'ZIP_STATE_MISMATCH'
    ZIP_NOT_FOUND = 'ZIP_NOT_FOUND'
    STATE_NOT_FOUND = 'STATE_NOT_FOUND'
    INVALID_ZIP = 'INVALID_ZIP'

    class << self
      def call(zipcode:, state_name:)
        zip = normalize_zip(zipcode)
        return invalid_zip_result(zipcode) unless zip

        state_code = state_code_from_name(state_name)
        return state_not_found_result(state_name) unless state_code

        std_state = StdState.with_postal_name(state_code).first
        return state_not_found_result(state_name) unless std_state

        zip_exists = StdZipcode.with_zip_code(zip).exists?
        return zip_not_found_result(zipcode) unless zip_exists

        validate_match(zip:, state_code:, std_state:)
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

      def success_result
        ZipStateValidationResult.new(valid: true)
      end

      def error_result(error_code:, error_message:)
        ZipStateValidationResult.new(
          valid: false,
          error_code:,
          error_message:
        )
      end

      def mismatch_result(zip:, state_code:)
        error_result(
          error_code: ZIP_STATE_MISMATCH,
          error_message: "Zip Code #{zip} does not belong to state #{state_code}."
        )
      end

      def invalid_zip_result(zipcode)
        error_result(
          error_code: INVALID_ZIP,
          error_message: "Invalid Zip Code: #{zipcode}."
        )
      end

      def state_not_found_result(state_name)
        error_result(
          error_code: STATE_NOT_FOUND,
          error_message: "Check State format: #{state_name}."
        )
      end

      def zip_not_found_result(zipcode)
        error_result(
          error_code: ZIP_NOT_FOUND,
          error_message: "Zip not found: #{zipcode}."
        )
      end

      def validate_match(zip:, state_code:, std_state:)
        if StdZipcode.for_zip_and_state(zip, std_state.id).exists?
          success_result
        else
          mismatch_result(zip:, state_code:)
        end
      end
    end
  end
end
