# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class Form8940Document < EvssDocument
      FORM_ID = '21-8940' # form id for PTSD IU
      DOC_TYPE = 'L149'

      def initialize(submission)
        parsed_form = JSON.parse(submission.form_to_json(Form526Submission::FORM_8940))
        form_content = parse_8940(parsed_form.deep_dup)

        @pdf_path = generate_stamp_pdf(form_content, submission.submitted_claim_id, FORM_ID) if form_content.present?
        upload_data = get_evss_claim_metadata(@pdf_path, DOC_TYPE)
        @document_data = create_document_data(submission.submitted_claim_id, upload_data, DOC_TYPE)
      end

      private

      def parse_8940(parsed_form)
        return '' if parsed_form['unemployability'].empty?
        parsed_form
      end
    end
  end
end
