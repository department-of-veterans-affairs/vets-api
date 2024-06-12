# frozen_string_literal: true

module ClaimsApi
  class Form526ErrorMapper
    FORM_526_ERROR_DICTIONARY = {
      InProcess: %w['This claim is already in progress'],
      marshalError: %w['A marshalling error occurred.'],
      startBatchJobError: %w['There was an internal error'],
      submit_establishClaim_serviceError: %w['The claim failed to establish'],
      submit_load_vaOffice_serviceError: %w['VA Office service error'],
      submit_load_benefitClaim_serviceError: %w[A service error occurre while loading the claim],
      submit_save_draftForm_serviceError: %w[A service error occurred during the claim submission],
      submit_save_draftForm_PIFInUse: %w[There was a problem with the draft form which was already in use],
      submit: %w['The claim could not be established'],
      disabled: %w['this claim has been disabled'],
      submit_save_draftForm_MaxEPCode: %w['This claim could not be established. The Maximum number of EP codes have been reached for this benefit type claim code'], # rubocop:disable Layout/LineLength
      submit_noRetryError: %w['This job is no longer able to be re-tried'],
      header_va_eauth_birlsfilenumber_Invalid: %w[There is a problem with your birls file number please contact...]
    }.freeze

    def initialize(error)
      @error = error
    end

    def get_details
      key = if @error[:key].include?('form526')
              @error[:key].slice!('form526').gsub('.', '_')
            else
              @error[:key].gsub('.', '_')
            end
      err_info = @error[:detail] || @error[:text]
      FORM_526_ERROR_DICTIONARY[key.to_sym].presence ||
        "The claim could not be established - #{err_info}. Hint: #{@error[:key]}"
    end
  end
end
