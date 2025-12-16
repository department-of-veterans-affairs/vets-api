# frozen_string_literal: true

require 'burials/monitor'
require 'burials/notification_email'
require 'burials/pdf_stamper'
require 'lighthouse/benefits_intake/metadata'
require 'lighthouse/benefits_intake/service'

module Burials
  module BenefitsIntake
    # sidekig job to send burial pdfs to Lighthouse:BenefitsIntake API
    # @see https://developer.va.gov/explore/api/benefits-intake/docs
    class SubmitClaimJob
      include Sidekiq::Job

      # generic job processing error
      class BurialsBenefitIntakeError < StandardError; end

      # retry for 2d 1h 47m 12s
      # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
      sidekiq_options retry: 16, queue: 'low'

      # retry exhaustion
      sidekiq_retries_exhausted do |msg|
        begin
          claim = Burials::SavedClaim.find(msg['args'].first)
        rescue
          claim = nil
        end
        monitor = Burials::Monitor.new
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
        @form_path = generate_form_pdf
        @attachment_paths = generate_attachment_pdfs
        @metadata = generate_metadata

        upload_document
        monitor.track_submission_success(@claim, @intake_service, @user_account_uuid)

        Flipper.enabled?(:burial_submitted_email_notification) ? send_submitted_email : send_confirmation_email

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
      # @raise [BurialsBenefitIntakeError] if unable to find claim
      #
      # @param (see #perform)
      def init(saved_claim_id, user_account_uuid)
        @user_account_uuid = user_account_uuid
        @user_account = UserAccount.find(@user_account_uuid) unless @user_account_uuid.nil?
        # UserAccount.find will raise an error if unable to find the user_account record

        @claim = Burials::SavedClaim.find(saved_claim_id)
        raise BurialsBenefitIntakeError, "Unable to find Burials::SavedClaim #{saved_claim_id}" unless @claim

        @intake_service = ::BenefitsIntake::Service.new
      end

      # Create a monitor to be used for _this_ job
      # @see Burials::Monitor
      def monitor
        @monitor ||= Burials::Monitor.new
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
      # @param stamp_set [String|Symbol] the stamps to apply
      #
      # @return [String] path to stamped PDF
      def process_document(file_path, stamp_set)
        document = Burials::PDFStamper.new(stamp_set).run(file_path, timestamp: @claim.created_at)

        @intake_service.valid_document?(document:)
      end

      # Upload generated pdf to Benefits Intake API
      #
      # @raise [BurialsBenefitIntakeError] on upload failure
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
        raise BurialsBenefitIntakeError, response.to_s unless response.success?
      end

      # Generate form PDF based on feature flag
      #
      # @return [String] path to processed PDF document
      def generate_form_pdf
        if Flipper.enabled?(:burial_extras_redesign_enabled)
          pdf_path = @claim.to_pdf(@claim.id, { extras_redesign: true, omit_esign_stamp: true })
          process_document(pdf_path, :burials_generated_claim)
        else
          process_document(@claim.to_pdf, :burials_generated_claim)
        end
      end

      # Generate the form attachment pdfs
      #
      # @return [Array<String>] path to processed PDF document
      def generate_attachment_pdfs
        @claim.persistent_attachments.map { |pa| process_document(pa.to_pdf, :burials_received_at) }
      end

      # Generate form metadata to send in upload to Benefits Intake API
      #
      # @see SavedClaim.parsed_form
      # @see BenefitsIntake::Metadata#generate
      #
      # @return [Hash] generated metadata for upload
      def generate_metadata
        form = @claim.parsed_form
        veteran_full_name = form['veteranFullName']
        address = form['claimantAddress'] || form['veteranAddress']

        # also validates/manipulates the metadata
        ::BenefitsIntake::Metadata.generate(
          veteran_full_name['first'],
          veteran_full_name['last'],
          form['vaFileNumber'] || form['veteranSocialSecurityNumber'],
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

      # VANotify job to send email to veteran
      def send_confirmation_email
        Burials::NotificationEmail.new(@claim.id).deliver(:confirmation)
      rescue => e
        monitor.track_send_email_failure(@claim, @intake_service, @user_account_uuid, 'confirmation', e)
      end

      # VANotify job to send Submission in Progress email to veteran
      def send_submitted_email
        Burials::NotificationEmail.new(@claim.id).deliver(:submitted)
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
