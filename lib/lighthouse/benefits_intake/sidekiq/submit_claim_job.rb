# frozen_string_literal: true

require 'lighthouse/benefits_intake/metadata'
require 'lighthouse/benefits_intake/monitor'
require 'lighthouse/benefits_intake/service'
require 'pdf_utilities/pdf_stamper'

module BenefitsIntake
  # generic job for submitting a claim to Lighthouse Benefits Intake
  class SubmitClaimJob
    include Sidekiq::Job

    # generic job processing error
    class BenefitsIntakeError < StandardError; end

    # retry for 2d 1h 47m 12s
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
    sidekiq_options retry: 16, queue: 'low'

    # retry exhaustion
    sidekiq_retries_exhausted do |msg|
      claim = begin
        ::SavedClaim.find(msg['args'][0])
      rescue
        nil
      end

      config = msg['args'][2] || {}
      if claim.present? && config[:kafka_submit_event]
        user_icn = UserAccount.find_by(id: msg['args'][1])&.icn.to_s

        Kafka.submit_event(
          icn: user_icn,
          current_id: claim.confirmation_number.to_s,
          submission_name: claim.form_id,
          state: Kafka::State::ERROR
        )
      end

      monitor = BenefitsIntake::Monitor.new
      monitor.track_submission_exhaustion(msg, claim)
    end

    # Process claim pdfs and upload to Benefits Intake API
    # On success send email
    #
    # @param saved_claim_id [Integer] the claim id
    # @param user_account_uuid [UUID] the user submitting the form
    # @param config [Mixed] key-value pairs for process steps
    # @option config [Symbol|String] :email_type the email template to be sent on success
    # @option config [Symbol|Array<Hash>] :claim_stamp_set stamp set name or list to apply to generated pdf
    # @option config [Symbol|Array<Hash>] :attachment_stamp_set stamp set name or list to apply to evidence pdf
    # @option config [String] :source the `source` to be recorded in the metadata for the upload; default: class name
    # @option config [Boolean] :kafka_submit_event flag to send event data to Kafka
    #
    # @return [UUID] benefits intake upload uuid
    def perform(saved_claim_id, user_account_uuid = nil, **config)
      init(saved_claim_id, user_account_uuid, config || {})

      generate_form_pdf
      generate_attachment_pdfs
      generate_metadata

      upload_claim_to_lighthouse

      send_claim_email
      monitor.track_submission_success(claim, service, user_account_uuid)

      benefits_intake_uuid
    rescue => e
      monitor.track_submission_retry(claim, service, user_account_uuid, e)
      submission_attempt&.fail!
      raise e
    ensure
      cleanup_file_paths
    end

    private

    attr_reader :config, :claim, :service, :form_path, :attachment_paths, :metadata, :submission, :submission_attempt

    # get the user account uuid
    def user_account_uuid
      @user_account&.id
    end

    # get the benefits intake uuid for _this_ attempt
    def benefits_intake_uuid
      @service&.uuid
    end

    # get the email type to send when job is successful
    def email_type
      @config[:email_type]
    end

    # get the stamp set to be used on the generated pdf of the claim
    def claim_stamp_set
      @config[:claim_stamp_set] || default_stamp_set
    end

    # get the stamp set to be used on the claim evidence (attachments)
    def attachment_stamp_set
      @config[:attachment_stamp_set] || default_stamp_set
    end

    # the default stamp set to be used if none specified in config
    def default_stamp_set
      default = [{
        text: 'VA.GOV',
        timestamp: nil,
        x: 5,
        y: 5
      }]

      ::PDFUtilities::PDFStamper.get_stamp_set(:vagov_received_at) || default
    end

    # Create a monitor to be used for _this_ job
    # @see Logging::BaseMonitor
    def monitor
      @monitor ||= BenefitsIntake::Monitor.new
    end

    # Instantiate instance variables for _this_ job
    #
    # @raise [ActiveRecord::RecordNotFound] if unable to find UserAccount
    # @raise [BenefitIntakeError] if unable to find claim
    #
    # @param (see #perform)
    def init(saved_claim_id, user_account_uuid, config)
      if user_account_uuid.present?
        # UserAccount.find should raise an error if unable to find the user_account record
        @user_account = begin
          ::UserAccount.find(user_account_uuid)
        rescue
          nil
        end
        raise BenefitsIntakeError, "Unable to find ::UserAccount #{user_account_uuid}" unless @user_account
      end

      @claim = begin
        ::SavedClaim.find(saved_claim_id)
      rescue
        nil
      end
      raise BenefitsIntakeError, "Unable to find ::SavedClaim #{saved_claim_id}" unless @claim

      @config = config || {}

      @service = ::BenefitsIntake::Service.new
    rescue BenefitsIntakeError => e
      sidekiq_options retry: false
      raise e
    end

    # Generate form PDF
    #
    # @return [String] path to processed PDF
    def generate_form_pdf
      @form_path = process_document(claim.to_pdf, claim_stamp_set)
    end

    # Generate the form attachment pdfs
    #
    # @return [Array<String>] path to processed PDF
    def generate_attachment_pdfs
      @attachment_paths = claim.persistent_attachments.map { |pa| process_document(pa.to_pdf, attachment_stamp_set) }
    end

    # Create a temp stamped PDF and validate the PDF satisfies Benefits Intake specification
    #
    # @param file_path [String] pdf file path
    # @param stamp_set [String|Array<Hash>] the identifier for a stamp set or an array of stamps
    #
    # @return [String] path to stamped PDF
    def process_document(file_path, stamp_set)
      document = ::PDFUtilities::PDFStamper.new(stamp_set).run(file_path, timestamp: claim.created_at)
      service.valid_document?(document:)
    end

    # Generate form metadata to send in upload to Benefits Intake API
    #
    # @see SavedClaim.parsed_form
    # @see BenefitsIntake::Metadata#generate
    #
    # @return [Hash] generated metadata for upload
    def generate_metadata
      # also validates/maniuplates the metadata
      @metadata = ::BenefitsIntake::Metadata.generate(
        claim.veteran_first_name,
        claim.veteran_last_name,
        claim.veteran_filenumber,
        claim.postal_code,
        config[:source] || self.class.to_s,
        claim.form_id,
        claim.business_line
      )
    end

    # Upload generated pdf to Benefits Intake API
    def upload_claim_to_lighthouse
      monitor.track_submission_begun(claim, service, user_account_uuid)

      # upload must be performed within 15 minutes of this request
      service.request_upload
      lighthouse_submission_polling

      payload = {
        upload_url: service.location,
        document: form_path,
        metadata: metadata.to_json,
        attachments: attachment_paths
      }

      monitor.track_submission_attempted(claim, service, user_account_uuid, payload)
      response = service.perform_upload(**payload)
      raise BenefitsIntakeError, response.to_s unless response.success?
    end

    # Insert submission polling entries
    def lighthouse_submission_polling
      lighthouse_submission = {
        form_id: claim.form_id,
        reference_data: claim.to_json,
        saved_claim: claim
      }

      Lighthouse::SubmissionAttempt.transaction do
        @submission = Lighthouse::Submission.create(**lighthouse_submission)
        @submission_attempt = Lighthouse::SubmissionAttempt.create(submission:, benefits_intake_uuid:)
      end

      Datadog::Tracing.active_trace&.set_tag('benefits_intake_uuid', benefits_intake_uuid)
    end

    # send submission in progress email to veteran
    #
    def send_claim_email
      claim.try(:send_email, email_type) if email_type
    rescue => e
      monitor.track_send_email_failure(claim, service, user_account_uuid, email_type, e)
    end

    # Delete temporary stamped PDF files for this job instance
    # catches any error, logs but does NOT re-raise - prevent job retry
    def cleanup_file_paths
      Common::FileHelpers.delete_file_if_exists(form_path) if form_path
      attachment_paths&.each { |p| Common::FileHelpers.delete_file_if_exists(p) }
    rescue => e
      monitor.track_file_cleanup_error(claim, service, user_account_uuid, e)
    end

    # end module BenefitsIntake
  end

  # end module BenefitsIntake
end
