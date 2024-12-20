# frozen_string_literal: true

module ClaimsApi
  module V2
    module Error
      class LighthouseErrorMapper
        LIGHTHOUSE_ERROR_DICTIONARY = {
          InProcess: 'This claim is already in progress',
          marshalError: 'A marshalling error occurred.',
          startBatchJobError: 'There was an internal error',
          submit_establishClaim_serviceError: 'The claim failed to establish',
          submit_load_vaOffice_serviceError: 'VA Office service error',
          submit_load_benefitClaim_serviceError: 'A service error occurre while loading the claim',
          submit_save_draftForm_serviceError: 'A service error occurred during the claim submission',
          submit_save_draftForm_PIFInUse: 'There was a problem with the draft form which was already in use',
          submit: 'The claim could not be established',
          disabled: 'this claim has been disabled',
          submit_save_draftForm_MaxEPCode: 'The Maximum number of EP codes have been reached for this benefit type claim code', # rubocop:disable Layout/LineLength
          submit_noRetryError: 'Claim could not be established. Retries will fail.',
          header_va_eauth_birlsfilenumber_Invalid: 'There is a problem with your birls file number. Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.' # rubocop:disable Layout/LineLength
        }.freeze

        def initialize(error)
          @error = error
        end

        def get_details
          key = if @error[:key].include?('form526')
                  @error[:key][8..].gsub('.', '_')
                else
                  @error[:key].gsub('.', '_')
                end
          err_info = @error[:detail] || @error[:text]
          if LIGHTHOUSE_ERROR_DICTIONARY[key.to_sym].presence
            LIGHTHOUSE_ERROR_DICTIONARY[key.to_sym]
          else
            "The claim could not be established - #{err_info}."
          end
        end
      end
    end
  end
end
