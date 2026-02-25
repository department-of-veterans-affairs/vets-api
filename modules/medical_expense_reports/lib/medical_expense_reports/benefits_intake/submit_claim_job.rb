# frozen_string_literal: true

require 'ibm/service'
require 'lighthouse/benefits_intake/service'
require 'lighthouse/benefits_intake/metadata'
require 'medical_expense_reports/notification_email'
require 'medical_expense_reports/monitor'
require 'pdf_utilities/datestamp_pdf'

require 'bigdecimal'
require 'date'

module MedicalExpenseReports
  module BenefitsIntake
    # Sidekiq job to send pension pdf to Lighthouse:BenefitsIntake API
    # @see https://developer.va.gov/explore/api/benefits-intake/docs
    class SubmitClaimJob
      include Sidekiq::Job

      # Error if "Unable to find MedicalExpenseReports::SavedClaim"
      class MedicalExpenseReportsBenefitIntakeError < StandardError; end

      # retry for  2d 1h 47m 12s
      # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
      sidekiq_options retry: 16, queue: 'low'
      sidekiq_retries_exhausted do |msg|
        ia_monitor = MedicalExpenseReports::Monitor.new
        begin
          claim = MedicalExpenseReports::SavedClaim.find(msg['args'].first)
        rescue
          claim = nil
        end
        ia_monitor.track_submission_exhaustion(msg, claim)
      end

      ##
      # Process pdfs and upload to Benefits Intake API
      #
      # @param saved_claim_id [Integer] the claim id
      # @param user_account_uuid [UUID] the user submitting the form
      #
      # @return [UUID] benefits intake upload uuid
      #
      def perform(saved_claim_id, user_account_uuid = nil)
        return unless Flipper.enabled?(:medical_expense_reports_form_enabled)

        init(saved_claim_id, user_account_uuid)
        process_submission
      rescue => e
        monitor.track_submission_retry(@claim, @intake_service, @user_account_uuid, e)
        @lighthouse_submission_attempt&.fail!
        raise e
      ensure
        cleanup_file_paths
      end

      private

      ##
      # Handle the document generation, upload flow, and post-submission hooks.
      #
      # @return [String] the intake service UUID for the submission
      def process_submission
        # generate and validate claim pdf documents
        @form_path = process_document(
          @claim.to_pdf(
            @claim.id,
            extras_redesign: true,
            omit_esign_stamp: true
          )
        )
        @attachment_paths = @claim.persistent_attachments.map { |pa| process_document(pa.to_pdf) }
        form = @claim.parsed_form
        @metadata = generate_metadata(form)
        @ibm_payload = @claim.to_ibm # build_ibm_payload(form)

        # upload must be performed within 15 minutes of this request
        upload_document

        send_submitted_email
        monitor.track_submission_success(@claim, @intake_service, @user_account_uuid)

        @intake_service.uuid
      end

      # Number of in-home care rows IBM expects.
      IN_HOME_ROW_COUNT = 8

      # Number of medical expense rows IBM expects.
      MED_EXPENSE_ROW_COUNT = 14

      # Number of travel rows IBM expects.
      TRAVEL_ROW_COUNT = 12

      # Normalize values that represent child/dependent recipients.
      CHILD_RECIPIENTS = %w[CHILD DEPENDENT].freeze

      # Instantiate instance variables for _this_ job
      def init(saved_claim_id, user_account_uuid)
        @user_account_uuid = user_account_uuid
        @user_account = UserAccount.find(@user_account_uuid) if @user_account_uuid.present?
        # UserAccount.find will raise an error if unable to find the user_account record

        @claim = MedicalExpenseReports::SavedClaim.find(saved_claim_id)
        unless @claim
          raise MedicalExpenseReportsBenefitIntakeError,
                "Unable to find MedicalExpenseReports::SavedClaim #{saved_claim_id}"
        end

        @intake_service = ::BenefitsIntake::Service.new
      end

      # Create a monitor to be used for _this_ job
      # @see MedicalExpenseReports::Monitor
      def monitor
        @monitor ||= MedicalExpenseReports::Monitor.new
      end

      # Create a temp stamped PDF and validate the PDF satisfies Benefits Intake specification
      #
      # @param [String] file_path
      #
      # @return [String] path to stamped PDF
      def process_document(file_path)
        document = PDFUtilities::DatestampPdf.new(file_path).run(text: 'VA.GOV', x: 5, y: 5)
        document = PDFUtilities::DatestampPdf.new(document).run(
          text: 'FDC Reviewed - VA.gov Submission',
          x: 429,
          y: 770,
          text_only: true
        )

        @intake_service.valid_document?(document:)
      end

      # Generate form metadata to send in upload to Benefits Intake API
      #
      # @see https://developer.va.gov/explore/api/benefits-intake/docs
      # @see SavedClaim.parsed_form
      # @see BenefitsIntake::Metadata
      #
      # @return [Hash]
      # Generate metadata for Benefits Intake upload, deriving veteran and claimant details.
      #
      # @param form [Hash]
      # @return [Hash]
      def generate_metadata(form)
        address = form['claimantAddress'] || form['veteranAddress']

        # also validates/manipulates the metadata
        ::BenefitsIntake::Metadata.generate(
          form['veteranFullName']['first'],
          form['veteranFullName']['last'],
          form['vaFileNumber'] || form['veteranSocialSecurityNumber'],
          address['postalCode'],
          'va_gov_bio_huntridge',
          @claim.form_id,
          @claim.business_line
        )
      end

      # Upload generated pdf to Benefits Intake API
      def upload_document
        @intake_service.request_upload
        monitor.track_submission_begun(@claim, @intake_service, @user_account_uuid)
        lighthouse_submission_polling

        payload = {
          upload_url: @intake_service.location,
          document: @form_path,
          metadata: @metadata.to_json,
          attachments: @attachment_paths
        }
        tracked_payload = payload.merge(
          ibm_payload_present: @ibm_payload.present?,
          ibm_payload_field_count: @ibm_payload&.keys&.count
        )

        monitor.track_submission_attempted(@claim, @intake_service, @user_account_uuid, tracked_payload)

        response = @intake_service.perform_upload(**payload)

        govcio_upload if response.success?

        raise MedicalExpenseReportsBenefitIntakeError, response.to_s unless response.success?
      end

      # Upload to IBM MMS if the govcio flipper is enabled
      def govcio_upload
        if Flipper.enabled?(:medical_expense_reports_govcio_mms)
          ibm_service = Ibm::Service.new
          ibm_service.upload_form(form: @ibm_payload.to_json, guid: @intake_service.uuid)
        end
      end

      # Insert submission polling entries
      def lighthouse_submission_polling
        lighthouse_submission = {
          form_id: @claim.form_id,
          reference_data: @claim.to_json,
          saved_claim: @claim
        }

        Lighthouse::SubmissionAttempt.transaction do
          @lighthouse_submission = Lighthouse::Submission.create(**lighthouse_submission)
          @lighthouse_submission_attempt =
            Lighthouse::SubmissionAttempt.create(submission: @lighthouse_submission,
                                                 benefits_intake_uuid: @intake_service.uuid)
        end

        Datadog::Tracing.active_trace&.set_tag('benefits_intake_uuid', @intake_service.uuid)
      end

      # VANotify job to send Submission in Progress email to veteran
      def send_submitted_email
        MedicalExpenseReports::NotificationEmail.new(@claim.id).deliver(:submitted)
      rescue => e
        monitor.track_send_email_failure(@claim, @intake_service, @user_account_uuid, 'submitted', e)
      end

      # Delete temporary stamped PDF files for this instance.
      def cleanup_file_paths
        Common::FileHelpers.delete_file_if_exists(@form_path) if @form_path
        @attachment_paths&.each { |p| Common::FileHelpers.delete_file_if_exists(p) }
      rescue => e
        monitor.track_file_cleanup_error(@claim, @intake_service, @user_account_uuid, e)
      end
    end
  end
end
