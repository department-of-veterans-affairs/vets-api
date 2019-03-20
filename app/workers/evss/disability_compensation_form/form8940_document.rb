# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    # Document generator for the 8940 form
    #
    # @return [EVSSClaimDocument] An EVSS claim document ready for submission
    #
    class Form8940Document < EvssDocument
      FORM_ID = '21-8940' # form id for PTSD IU
      DOC_TYPE = 'L149'

      def initialize(submission)
        form_content = parse_8940(submission.form[Form526Submission::FORM_8940])

        @pdf_path = generate_stamp_pdf(form_content, submission.submitted_claim_id, FORM_ID) if form_content.present?
        upload_data = get_evss_claim_metadata(@pdf_path, DOC_TYPE)
        @document_data = create_document_data(submission.submitted_claim_id, upload_data, DOC_TYPE)
      end

      private

      def parse_8940(parsed_form)
        return '' if parsed_form['unemployability'].empty?
        parsed_form.deep_dup
      end
    end
  end
end
