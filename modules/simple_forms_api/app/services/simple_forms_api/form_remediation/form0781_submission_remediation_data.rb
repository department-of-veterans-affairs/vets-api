# frozen_string_literal: true

module SimpleFormsApi
  module FormRemediation
    class Form0781
      def submission_date_stamps(timestamp)
        [
          {
            coords: [460, 710],
            text: 'Application Submitted:',
            page: 0,
            font_size: 12
          },
          {
            coords: [460, 690],
            text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
            page: 0,
            font_size: 12
          }
        ]
      end

      def desired_stamps
        []
      end
    end

    class Form0781SubmissionRemediationData < SubmissionRemediationData
      attr_reader :form_key

      def initialize(id:, config:, form_key:)
        @form_key = form_key
        super(id:, config:)
      end

      def hydrate!
        form_content = fetch_form_content!
        submitted_claim_id = submission.submitted_claim_id
        submission_date = submission&.created_at

        form_content = form_content.merge(
          { 'signatureDate' => submission_date&.in_time_zone('Central Time (US & Canada)') }
        )

        # Require when needed during runtime, not during file load
        require 'evss/disability_compensation_form/submit_form0781' if config.form_id.nil?

        @file_path = PdfFill::Filler.fill_ancillary_form(
          form_content,
          submitted_claim_id,
          config.form_id
        )

        SimpleFormsApi::PdfStamper.new(
          stamped_template_path: file_path,
          form: Form0781.new,
          timestamp: submission_date
        ).stamp_pdf

        self
      rescue => e
        config.handle_error('Error hydrating submission', e)
      end

      private

      attr_reader :config

      def fetch_form_content!
        parsed = JSON.parse(submission.form_to_json(Form526Submission::FORM_0781))
        content = parsed[form_key]

        # Fallback for pre-2019 flat payload (incidents at root)
        content = parsed if form_key == 'form0781' && content.blank? && parsed.key?('incidents')

        if content.blank?
          raise Common::Exceptions::RecordNotFound,
                "No #{form_key} payload for submission ##{submission.id}"
        end

        content
      end

      def fetch_submission(id)
        @submission = Form526Submission.find(id)
      end
    end
  end
end
