# frozen_string_literal: true

module AskVAApi
  module ZipStateValidation
    class ZipStateValidator
      ZIP_STATE_MISMATCH = 'ZIP_STATE_MISMATCH'
      ZIP_NOT_FOUND = 'ZIP_NOT_FOUND'
      STATE_NOT_FOUND = 'STATE_NOT_FOUND'
      INVALID_ZIP = 'INVALID_ZIP'

      # Validates that a given zip code belongs to a given U.S. state.

      # This validator normalizes and verifies a zip/state pair using existing
      # `std_states` and `std_zipcodes` data and returns a standardized result
      # object with success or a specific error code.

      # Intended for use by the Ask VA API to ensure zip/state consistency
      # before downstream processing.

      class << self
        # Performs ZIP/state validation.

        # @param zip_code [String] ZIP code input (supports ZIP+4; normalized internally)
        # @param state_code [String] Two-letter state code
        # @return [ZipStateValidationResult] result indicating success or failure,
        # including an error code and message when invalid
        def call(zip_code:, state_code:)
          normalized_zip_code = normalize_zip(zip_code)
          return invalid_zip_result(zip_code) unless normalized_zip_code

          normalized_state_code = normalize_state_code(state_code)
          return state_not_found_result(state_code) unless normalized_state_code

          state_id = StdState.with_postal_name(normalized_state_code).pick(:id)
          return state_not_found_result(state_code) unless state_id

          zip_exists = StdZipcode.with_zip_code(normalized_zip_code).exists?
          return zip_not_found_result(zip_code) unless zip_exists

          validate_match(zip_code: normalized_zip_code, state_id:, state_code: normalized_state_code)
        end

        private

        def normalize_zip(zip_code)
          # convert full zip to a 5 digit zip
          zip_code = zip_code.to_s.strip.split('-').first
          return nil unless zip_code.match?(/\A\d{5}\z/)

          zip_code
        end

        def normalize_state_code(state_code)
          state_code = state_code.to_s.strip.upcase
          return nil unless state_code.match?(/\A[A-Z]{2}\z/)

          state_code
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

        def mismatch_result(zip_code:, state_code:)
          error_result(
            error_code: ZIP_STATE_MISMATCH,
            error_message: "Zip Code #{zip_code} does not belong to state #{state_code}."
          )
        end

        def invalid_zip_result(zip_code)
          error_result(
            error_code: INVALID_ZIP,
            error_message: "Invalid Zip Code: #{zip_code}."
          )
        end

        def state_not_found_result(state_code)
          error_result(
            error_code: STATE_NOT_FOUND,
            error_message: "Check State format: #{state_code}."
          )
        end

        def zip_not_found_result(zip_code)
          error_result(
            error_code: ZIP_NOT_FOUND,
            error_message: "Zip not found: #{zip_code}."
          )
        end

        def validate_match(zip_code:, state_id:, state_code:)
          if StdZipcode.for_zip_and_state(zip_code, state_id).exists?
            success_result
          else
            mismatch_result(zip_code:, state_code:)
          end
        end
      end
    end
  end
end
