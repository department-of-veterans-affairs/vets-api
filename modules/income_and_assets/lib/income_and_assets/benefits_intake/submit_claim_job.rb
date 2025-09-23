# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'lighthouse/benefits_intake/metadata'
require 'income_and_assets/notification_email'
require 'income_and_assets/monitor'
require 'pdf_utilities/datestamp_pdf'

module IncomeAndAssets
  module BenefitsIntake
    # Sidekig job to send pension pdf to Lighthouse:BenefitsIntake API
    # @see https://developer.va.gov/explore/api/benefits-intake/docs
    class SubmitClaimJob
      include Sidekiq::Job

      # Error if "Unable to find IncomeAndAssets::SavedClaim"
      class IncomeAndAssetsBenefitIntakeError < StandardError; end

      # retry for  2d 1h 47m 12s
      # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
      sidekiq_options retry: 16, queue: 'low'
      sidekiq_retries_exhausted do |msg|
        ia_monitor = IncomeAndAssets::Monitor.new
        begin
          claim = IncomeAndAssets::SavedClaim.find(msg['args'].first)
        rescue
          claim = nil
        end
        ia_monitor.track_submission_exhaustion(msg, claim)
      end

      ##
      # Process income and assets pdfs and upload to Benefits Intake API
      #
      # @param saved_claim_id [Integer] the pension claim id
      #
      # @return [UUID] benefits intake upload uuid
      #
      def perform(saved_claim_id)
        init(saved_claim_id)

        # generate and validate claim pdf documents
        @form_path = process_document(@claim.to_pdf(@claim.id, { extras_redesign: true,
                                                                 omit_esign_stamp: true }))
        @attachment_paths = @claim.persistent_attachments.map { |pa| process_document(pa.to_pdf) }
        @metadata = generate_metadata

        # upload must be performed within 15 minutes of this request
        upload_document

        send_submitted_email
        monitor.track_submission_success(@claim, @intake_service, @claim.user_account_id)

        @intake_service.uuid
      rescue => e
        monitor.track_submission_retry(@claim, @intake_service, @claim&.user_account_id, e)
        @lighthouse_submission_attempt&.fail!
        raise e
      ensure
        cleanup_file_paths
      end

      private

      # Instantiate instance variables for _this_ job
      def init(saved_claim_id)
        @claim = IncomeAndAssets::SavedClaim.find(saved_claim_id)
        unless @claim
          raise IncomeAndAssetsBenefitIntakeError,
                "Unable to find IncomeAndAssets::SavedClaim #{saved_claim_id}"
        end

        # Check to make sure that the user_account_id points to an actual user_account record
        # UserAccount.find will raise an error if unable to find the user_account record
        UserAccount.find(@claim.user_account_id) if @claim.user_account_id.present?

        @intake_service = ::BenefitsIntake::Service.new
      end

      # Create a monitor to be used for _this_ job
      # @see IncomeAndAssets::Monitor
      def monitor
        @monitor ||= IncomeAndAssets::Monitor.new
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
      def generate_metadata
        form = @claim.parsed_form

        # also validates/maniuplates the metadata
        ::BenefitsIntake::Metadata.generate(
          form['veteranFullName']['first'],
          form['veteranFullName']['last'],
          form['vaFileNumber'] || form['veteranSocialSecurityNumber'],
          self.class.to_s,
          @claim.form_id,
          @claim.business_line
        )
      end

      # Upload generated pdf to Benefits Intake API
      def upload_document
        @intake_service.request_upload
        monitor.track_submission_begun(@claim, @intake_service, @claim.user_account_id)
        lighthouse_submission_polling

        payload = {
          upload_url: @intake_service.location,
          document: @form_path,
          metadata: @metadata.to_json,
          attachments: @attachment_paths
        }

        monitor.track_submission_attempted(@claim, @intake_service, @claim.user_account_id, payload)
        response = @intake_service.perform_upload(**payload)
        raise IncomeAndAssetsBenefitIntakeError, response.to_s unless response.success?
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
        IncomeAndAssets::NotificationEmail.new(@claim.id).deliver(:submitted)
      rescue => e
        monitor.track_send_email_failure(@claim, @intake_service, @claim.user_account_id, 'submitted', e)
      end

      # Delete temporary stamped PDF files for this instance.
      def cleanup_file_paths
        Common::FileHelpers.delete_file_if_exists(@form_path) if @form_path
        @attachment_paths&.each { |p| Common::FileHelpers.delete_file_if_exists(p) }
      rescue => e
        monitor.track_file_cleanup_error(@claim, @intake_service, @claim&.user_account_id, e)
      end
    end
  end
end
