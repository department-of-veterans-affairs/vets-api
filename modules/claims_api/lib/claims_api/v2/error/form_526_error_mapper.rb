# frozen_string_literal: true

module ClaimsApi
  class Form526ErrorMapper
    FORM_526_ERROR_DICTIONARY = {
      InProcess: ['This claim is already in progress'],
      marshalError: ['Slim shady'],
      startBatchJobError: ['There was an internal error, 500'],
      submit_establishClaim_serviceError: ['The claim failed to establish'],
      submit_load_vaOffice_serviceError: [],
      submit_load_benefitClaim_serviceError: [],
      submit_save_draftForm_serviceError: [],
      disabled: ['this claim/process has been disabled'],
      submit_save_draftForm_MaxEPCode: ["This user has reached it's maximum number of attempts.",
                                        'This claim could not be established. The Maximum number of EP codes have been reached for this benefit type claim code'], # rubocop:disable Layout/LineLength
      submit_save_draftForm_PIFInUse: [],
      submit_noRetryError: ['This job is no longer able to be re-tried']
    }.freeze

    def initialize(error)
      @error = error
    end

    def get_details
      if @error[:key].include?('form526')
        key = @error[:key].slice!('form526').gsub('.', '_')
        FORM_526_ERROR_DICTIONARY[key.to_sym]
      else
        @error[:detail] || "#{@error[:key]} - #{@error[:text]}"
      end
    end
  end
end
