# frozen_string_literal: true

require 'pdf_utilities/datestamp_pdf'
require 'dependents_verification/monitor'
require 'dependents_verification/notification_email'
require 'lighthouse/benefits_intake/metadata'
require 'lighthouse/benefits_intake/service'

module DependentsVerification
  module BenefitsIntake
    # Sidekiq job to send dependents_verification pdfs to Lighthouse:BenefitsIntake API
    # @see https://developer.va.gov/explore/api/benefits-intake/docs
    class SubmitClaimJob
      include Sidekiq::Job

      # generic job processing error
      class DependentsVerificationBenefitsIntakeError < StandardError; end

      # retry for 2d 1h 47m 12s
      # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
      sidekiq_options retry: 16, queue: 'low'

      # retry exhaustion
      sidekiq_retries_exhausted do |msg|
        begin
          claim = DependentsVerification::SavedClaim.find(msg['args'].first)
        rescue
          claim = nil
        end
        monitor = DependentsVerification::Monitor.new
        monitor.track_submission_exhaustion(msg, claim)
      end

      # Process claim pdfs and upload to Benefits Intake API
      # On success send email
      #
      # @param saved_claim_id [Integer] the claim id
      # @param user_account_uuid [UUID] the user submitting the form
      #
      # @return [UUID] benefits intake upload uuid
      def perform(saved_claim_id, user_account_uuid = nil)
        init(saved_claim_id, user_account_uuid)

        return if lighthouse_submission_pending_or_success

        # generate and validate claim pdf documents
        @form_path = process_document(@claim.to_pdf)
        @attachment_paths = @claim.persistent_attachments.map { |pa| process_document(pa.to_pdf) }
        @metadata = generate_metadata

        upload_document

        send_submitted_email
        monitor.track_submission_success(@claim, @intake_service, @user_account_uuid)

        @intake_service.uuid
      rescue => e
        monitor.track_submission_retry(@claim, @intake_service, @user_account_uuid, e)
        @lighthouse_submission_attempt&.fail!
        raise e
      ensure
        cleanup_file_paths
      end

      private

      # Instantiate instance variables for _this_ job
      #
      # @raise [ActiveRecord::RecordNotFound] if unable to find UserAccount
      # @raise [DependentsVerificationBenefitsIntakeError] if unable to find claim
      #
      # @param (see #perform)
      def init(saved_claim_id, user_account_uuid)
        @user_account_uuid = user_account_uuid
        @user_account = UserAccount.find(@user_account_uuid) unless @user_account_uuid.nil?
        # UserAccount.find will raise an error if unable to find the user_account record

        @claim = DependentsVerification::SavedClaim.find(saved_claim_id)
        unless @claim
          raise DependentsVerificationBenefitsIntakeError,
                "Unable to find DependentsVerification::SavedClaim #{saved_claim_id}"
        end

        @intake_service = ::BenefitsIntake::Service.new
      end

      # Create a monitor to be used for _this_ job
      # @see DependentsVerification::Monitor
      def monitor
        @monitor ||= DependentsVerification::Monitor.new
      end

      # Check Lighthouse::SubmissionAttempts for record with 'pending' or 'success'
      #
      # @return true if Lighthouse::SubmissionAttempt has 'pending' or 'success'
      # @return false if unable to find a Lighthouse::Submission or Lighthouse::SubmissionAttempt
      # not 'pending' or 'success'
      def lighthouse_submission_pending_or_success
        @claim&.lighthouse_submissions&.any? do |lighthouse_submission|
          lighthouse_submission.non_failure_attempt.present?
        end || false
      end

      # Create a temp stamped PDF and validate the PDF satisfies Benefits Intake specification
      #
      # @param file_path [String] pdf file path
      #
      # @return [String] path to stamped PDF
      def process_document(file_path)
        document = PDFUtilities::DatestampPdf.new(file_path).run(
          text: 'VA.GOV',
          timestamp: @claim.created_at,
          x: 5,
          y: 5
        )

        document = PDFUtilities::DatestampPdf.new(document).run(
          text: 'FDC Reviewed - VA.gov Submission',
          timestamp: @claim.created_at,
          x: 400,
          y: 770,
          text_only: true
        )

        @intake_service.valid_document?(document:)
      end

      # Upload generated pdf to Benefits Intake API
      #
      # @raise [DependentsVerificationBenefitsIntakeError] on upload failure
      def upload_document
        # upload must be performed within 15 minutes of this request
        @intake_service.request_upload
        monitor.track_submission_begun(@claim, @intake_service, @user_account_uuid)
        lighthouse_submission_polling

        payload = {
          upload_url: @intake_service.location,
          document: @form_path,
          metadata: @metadata.to_json,
          attachments: @attachment_paths
        }

        monitor.track_submission_attempted(@claim, @intake_service, @user_account_uuid, payload)
        response = @intake_service.perform_upload(**payload)
        raise DependentsVerificationBenefitsIntakeError, response.to_s unless response.success?
      end

      # Generate form metadata to send in upload to Benefits Intake API
      #
      # @see SavedClaim.parsed_form
      # @see BenefitsIntake::Metadata#generate
      #
      # @return [Hash] generated metadata for upload
      def generate_metadata
        form = @claim.parsed_form
        veteran_full_name = form['veteranInformation']['fullName']
        address = form['address']

        # also validates/manipulates the metadata
        ::BenefitsIntake::Metadata.generate(
          veteran_full_name['first'],
          veteran_full_name['last'],
          form['veteranInformation']['ssn'],
          address['postalCode'],
          self.class.to_s,
          @claim.form_id,
          @claim.business_line
        )
      end

      # Insert submission polling entries
      #
      # @see Lighthouse::Submission
      # @see Lighthouse::SubmissionAttempt
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
        DependentsVerification::NotificationEmail.new(@claim.id).deliver(:submitted)
      rescue => e
        monitor.track_send_email_failure(@claim, @intake_service, @user_account_uuid, 'submitted', e)
      end

      # Delete temporary stamped PDF files for this job instance
      # catches any error, logs but does NOT re-raise - prevent job retry
      def cleanup_file_paths
        Common::FileHelpers.delete_file_if_exists(@form_path) if @form_path
        @attachment_paths&.each { |p| Common::FileHelpers.delete_file_if_exists(p) }
      rescue => e
        monitor.track_file_cleanup_error(@claim, @intake_service, @user_account_uuid, e)
      end
    end
  end
end
