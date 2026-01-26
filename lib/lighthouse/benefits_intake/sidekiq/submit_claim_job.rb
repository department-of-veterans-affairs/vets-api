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
      claim = ::SavedClaim.find(msg['args'][0]) rescue nil

      if claim.present? && Flipper.enabled?(:pension_kafka_event_bus_submission_enabled)
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
    # @param user_uuid [UUID] the user submitting the form
    #
    # @return [UUID] benefits intake upload uuid
    def perform(saved_claim_id, user_account_uuid = nil)
      init(saved_claim_id, user_account_uuid)

      @form_path = generate_form_pdf
      @attachment_paths = generate_attachment_pdfs
      @metadata = generate_metadata

    rescue => e
      monitor.track_submission_retry(claim, service, user_account_uuid, e)
      @lighthouse_submission_attempt&.fail!
      raise e
    ensure
      cleanup_file_paths
    end

    private

    attr_reader :claim, :service

    def user_account_uuid
      @user_account&.id
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
    def init(saved_claim_id, user_account_uuid)
      if user_account_uuid.present?
        # UserAccount.find should raise an error if unable to find the user_account record
        @user_account = ::UserAccount.find(user_account_uuid) rescue nil
        raise BenefitsIntakeError, "Unable to find ::UserAccount #{user_account_uuid}" unless @user_account
      end

      @claim = ::SavedClaim.find(saved_claim_id) rescue nil
      raise BenefitsIntakeError, "Unable to find ::SavedClaim #{saved_claim_id}" unless @claim

      @service = ::BenefitsIntake::Service.new
    rescue BenefitsIntakeError e
      sidekiq_options retry: false
      raise e
    end

    # Generate form PDF
    #
    # @return [String] path to processed PDF document
    def generate_form_pdf
      stamp_set = :vagov_recieved_at
      process_document(@claim.to_pdf, stamp_set)
    end

    # Generate the form attachment pdfs
    #
    # @return [Array<String>] path to processed PDF document
    def generate_attachment_pdfs
      stamp_set = :vagov_recieved_at
      @claim.persistent_attachments.map { |pa| process_document(pa.to_pdf, stamp_set) }
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
      ::BenefitsIntake::Metadata.generate(
        claim.veteran_first_name,
        claim.veteran_last_name,
        claim.veteran_filenumber,
        claim.postal_code,
        self.class.to_s, # source
        claim.form_id,
        claim.business_line
      )
    end

    # Delete temporary stamped PDF files for this job instance
    # catches any error, logs but does NOT re-raise - prevent job retry
    def cleanup_file_paths
      Common::FileHelpers.delete_file_if_exists(@form_path) if @form_path
      @attachment_paths&.each { |p| Common::FileHelpers.delete_file_if_exists(p) }
    rescue => e
      monitor.track_file_cleanup_error(@claim, @intake_service, @user_account_uuid, e)
    end

    # end module BenefitsIntake
  end

  # end module BenefitsIntake
end
