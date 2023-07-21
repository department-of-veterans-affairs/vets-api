# frozen_string_literal: true

require 'disability_compensation/requests/form526_request_body'

module EVSS
  module DisabilityCompensationForm
    class Form526ToLighthouseTransform
      # takes known EVSS Form526Submission format and converts it to a Lighthouse request body
      # evss_data will look like JSON.parse(form526_submission.form_data)
      def transform(evss_data)
        form526 = evss_data['form526']
        lh_request_body = Requests::Form526.new
        lh_request_body.claimant_certification = true
        lh_request_body.claim_date = form526['claim_date'] if form526['claim_date']
        lh_request_body.claim_process_type = evss_claims_process_type(form526) # basic_info[:claim_process_type]

        lh_request_body
      end

      # returns "STANDARD_CLAIM_PROCESS", "BDD_PROGRAM", or "FDC_PROGRAM"
      # based off of a few attributes in the evss data
      def evss_claims_process_type(_form526)
        # TODO: replace with implementation
        'STANDARD_CLAIM_PROCESS'
      end
    end
  end
end
