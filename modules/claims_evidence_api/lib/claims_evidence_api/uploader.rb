# frozen_string_literal: true

require 'claims_evidence_api/exceptions'
require 'claims_evidence_api/monitor'
require 'claims_evidence_api/service/files'
require 'claims_evidence_api/validation'
require 'pdf_utilities/pdf_stamper'

module ClaimsEvidenceApi
  # Utility class for uploading claim evidence
  class Uploader
    attr_reader :attempt, :folder_identifier, :response, :submission

    # @param folder_identifier [String] the upload location; @see ClaimsEvidenceApi::FolderIdentifier
    def initialize(folder_identifier)
      @service = ClaimsEvidenceApi::Service::Files.new
      self.folder_identifier = folder_identifier
    end

    # change the folder_identifier being uploaded to
    # @see ClaimsEvidenceApi::FolderIdentifier
    def folder_identifier=(folder_identifier)
      @service.folder_identifier = @folder_identifier = folder_identifier
    end

    # upload claim and evidence pdfs
    # providing the `X_stamp_set` will perform stamping of the generated pdf
    #
    # @see PDFUtilities::PDFStamper
    #
    # @param saved_claim_id [Integer] the db id for the claim
    # @param claim_stamp_set [String|Array<Hash>] the identifier for a stamp set or an array of stamps
    # @param attachment_stamp_set [String|Array<Hash>] the identifier for a stamp set or an array of stamps
    #
    # @return [String] the claim pdf file_uuid
    def upload_saved_claim_evidence(saved_claim_id, claim_stamp_set = nil, attachment_stamp_set = nil)
      claim = SavedClaim.find(saved_claim_id)

      upload_evidence(saved_claim_id, stamp_set: claim_stamp_set)
      claim_file_uuid = submission.file_uuid

      # `submission` will be for the last uploaded attachment when done
      claim.persistent_attachments.each do |pa|
        upload_evidence(saved_claim_id, pa.id, stamp_set: attachment_stamp_set)
      end

      claim_file_uuid
    end

    # upload an evidence file
    # if `file_path` is provided it will be used instead of calling `to_pdf` on the evidence
    # providing `stamp_set` will perform stamping of the generated pdf
    #
    # @see PDFUtilities::PDFStamper
    #
    # @param saved_claim_id [Integer] the db id for the SavedClaim
    # @param persistent_attachment_id [Integer] the db id for the PersistentAttachment
    # @param file_path [String] file path of the evidence to upload; default nil
    # @param stamp_set [String|Array<Hash>] the identifier for a stamp set or an array of stamps
    # @param form_id [String] the form_id of the claim
    # @param doctype [Integer] the document type for the file; default to `document_type` of evidence
    #
    # @return [String] the file_uuid
    # rubocop:disable Metrics/ParameterLists
    def upload_evidence(saved_claim_id, persistent_attachment_id = nil, file_path: nil, stamp_set: nil, form_id: nil,
                        doctype: nil)
      # track the initial values provided for this upload
      context = { saved_claim_id:, persistent_attachment_id:, stamp_set:, form_id:, doctype: }
      monitor.track_upload_begun(**context)

      evidence = claim = SavedClaim.find(saved_claim_id)
      evidence = PersistentAttachment.find_by(id: persistent_attachment_id, saved_claim_id:) if persistent_attachment_id

      form_id ||= claim.form_id
      doctype ||= evidence.document_type

      file_path ||= evidence.to_pdf
      file_path = PDFUtilities::PDFStamper.new(stamp_set).run(file_path, timestamp: evidence.created_at) if stamp_set

      init_tracking(saved_claim_id, persistent_attachment_id, form_id:)
      submission.saved_claim = claim

      # several values may have been updated, so reassign the tracking context
      context = { saved_claim_id:, persistent_attachment_id:, stamp_set:, form_id:, doctype: }
      monitor.track_upload_attempt(**context)
      perform_upload(file_path, evidence.created_at, doctype)

      update_tracking
      monitor.track_upload_success(**context)

      submission.file_uuid
    rescue => e
      monitor.track_upload_failure(e.message, **context)
      attempt_failed(e)
      raise e
    end
    # rubocop:enable Metrics/ParameterLists

    private

    # instantiate the uploader monitor
    # @see ClaimsEvidenceApi::Monitor::Uploader
    def monitor
      @monitor ||= ClaimsEvidenceApi::Monitor::Uploader.new
    end

    # create/retrieve the submission record for the claim and attachment
    # and create a new submission_attempt
    #
    # @param saved_claim_id [Integer] the db id for the claim to be submitted
    # @param persistent_attachment_id [Integer] the db id for the attachment
    #
    # @return [ClaimsEvidenceApi::SubmissionAttempt]
    def init_tracking(saved_claim_id, persistent_attachment_id = nil, form_id:)
      @submission = ClaimsEvidenceApi::Submission.find_or_create_by(saved_claim_id:, persistent_attachment_id:,
                                                                    form_id:)

      submission.folder_identifier = @service.folder_identifier
      submission.save

      @attempt = submission.submission_attempts.create
      attempt.save
    end

    # upload the file
    # assembles the required metadata for the upload and updates the `attempt`
    #
    # @param file_path [String] file path of the pdf to upload
    # @param va_received_at [DateTime] datetime of when the va received the file
    # @param doctype [Integer|String] document type of the file
    def perform_upload(file_path, va_received_at = Time.zone.now, doctype = 10)
      attempt.metadata = provider_data = {
        contentSource: ClaimsEvidenceApi::CONTENT_SOURCE,
        dateVaReceivedDocument: format_datetime(va_received_at),
        documentTypeId: doctype
      }
      attempt.save

      @response = @service.upload(file_path, provider_data:)
    end

    # modify the file upload date to be in the expected zone and format
    #
    # @param datetime [DateTime] datetime of when the va received the file
    def format_datetime(datetime)
      DateTime.parse(datetime.to_s).in_time_zone(ClaimsEvidenceApi::TIMEZONE).strftime('%Y-%m-%d')
    end

    # update the tracking records with the result of the attempt
    # @raise [ClaimsEvidenceApi::Exceptions::VefsError] if upload is not successful
    def update_tracking
      submission.file_uuid = response.body['uuid']
      submission.save

      attempt.status = 'accepted'
      attempt.response = response.body
      attempt.save
    end

    # fail the current attempt, populating the error_message
    #
    # @param error [Error] the error which occurred
    def attempt_failed(error)
      return unless attempt

      error_message = error.try(:body) || error.message

      attempt.status = 'failed'
      attempt.error_message = error_message
      attempt.save
    end
  end

  # end ClaimsEvidenceApi
end
