# frozen_string_literal: true

require 'education_benefits_claims/monitor'

module EducationForm
  class SubmitEducationBenefitsClaimJob
    include Sidekiq::Job

    # Only process those forms types that are applicable
    FORMS_IDS = %w[22-0989].freeze

    class EducationBenefitClaimIntakeError < StandardError; end

    sidekiq_options retry: 16, queue: 'low'

    # retry exhaustion
    sidekiq_retries_exhausted do |msg|
      claim = begin
        SavedClaim.find(msg['args'].first)
      rescue
        nil
      end
      monitor = EducationBenefitsClaims::Monitor.new(claim)
      monitor.track_submission_exhaustion(msg, claim)
    end

    attr_accessor :monitor, :claim

    def perform(saved_claim_id, user_account_uuid = nil)
      @user_account_uuid = user_account_uuid
      @claim = SavedClaim.find(saved_claim_id)
      unless FORMS_IDS.include?(@claim.form_id)
        raise EducationBenefitClaimIntakeError,
              "SEBCJ: Invalid form id #{saved_claim_id}, #{@claim.form_id}"
      end

      @monitor = EducationBenefitsClaims::Monitor.new(claim)

      return if lighthouse_submission_pending_or_success

      # generate and validate claim pdf documents
      @form_path = generate_form_pdf
      @attachment_paths = generate_attachment_pdfs
      @metadata = claim.generate_benefits_intake_metadata

      upload_document
      monitor.track_submission_success(claim, intake_service, @user_account_uuid)

      intake_service.uuid
    rescue => e
      monitor&.track_submission_retry(claim, intake_service, @user_account_uuid, e)
      @lighthouse_submission_attempt&.fail!
      raise e
    ensure
      cleanup_file_paths
    end

    private

    def intake_service
      @intake_service ||= ::BenefitsIntake::Service.new
    end

    def lighthouse_submission_pending_or_success
      claim&.lighthouse_submissions&.any? do |lighthouse_submission|
        lighthouse_submission.non_failure_attempt.present?
      end || false
    end

    def generate_form_pdf
      pdf_path = claim.to_pdf
      process_document(pdf_path)
    end

    def generate_attachment_pdfs
      claim.persistent_attachments.map { |pa| process_document(pa.to_pdf) }
    end

    def process_document(file_path, stamp_set = default_stamp_set)
      document = ::PDFUtilities::PDFStamper.new(stamp_set).run(file_path, timestamp: claim.created_at)
      intake_service.valid_document?(document:)
    end

    def default_stamp_set
      default = [{
        text: 'VA.GOV',
        timestamp: nil,
        x: 5,
        y: 5
      }]

      stamp_set = ::PDFUtilities::PDFStamper.get_stamp_set(:vagov_received_at)
      stamp_set.presence || default
    end

    def upload_document
      intake_service.request_upload
      monitor.track_submission_begun(claim, intake_service, @user_account_uuid)
      create_lighthouse_submission_attempt

      payload = {
        upload_url: intake_service.location,
        document: @form_path,
        metadata: @metadata.to_json,
        attachments: @attachment_paths
      }

      monitor.track_submission_attempted(claim, intake_service, @user_account_uuid, payload)
      response = intake_service.perform_upload(**payload)
      raise EducationBenefitClaimIntakeError, response.to_s unless response.success?
    end

    def create_lighthouse_submission_attempt
      lighthouse_submission_params = {
        form_id: claim.form_id,
        reference_data: claim.to_json,
        saved_claim: claim
      }

      Lighthouse::SubmissionAttempt.transaction do
        lighthouse_submission = Lighthouse::Submission.create(**lighthouse_submission_params)
        @lighthouse_submission_attempt =
          Lighthouse::SubmissionAttempt.create(submission: lighthouse_submission,
                                               benefits_intake_uuid: intake_service.uuid)
      end
    end

    def cleanup_file_paths
      Common::FileHelpers.delete_file_if_exists(@form_path) if @form_path
      @attachment_paths&.each { |p| Common::FileHelpers.delete_file_if_exists(p) }
    rescue
      # don't raise on file removal failure
    end
  end
end
