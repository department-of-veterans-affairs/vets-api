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
      def hydrate!
        form_content = JSON.parse(submission.form_to_json(Form526Submission::FORM_0781))['form0781a']
        submitted_claim_id = submission.submitted_claim_id
        submission_date = submission&.created_at
        form_content = form_content.merge(
          { 'signatureDate' => submission_date&.in_time_zone('Central Time (US & Canada)') }
        )
        @file_path = PdfFill::Filler.fill_ancillary_form(
          form_content,
          submitted_claim_id,
          EVSS::DisabilityCompensationForm::SubmitForm0781::FORM_ID_0781A
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

      def fetch_submission(id)
        @submission = Form526Submission.find(id)
      end
    end
  end
end
