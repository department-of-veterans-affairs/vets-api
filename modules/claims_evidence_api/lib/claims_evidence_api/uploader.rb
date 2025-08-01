# frozen_string_literal: true

require 'claims_evidence_api/exceptions'
require 'claims_evidence_api/monitor'
require 'claims_evidence_api/service/files'
require 'pdf_utilities/pdf_stamper'

module ClaimsEvidenceApi
  # Utility class for uploading claim evidence
  class Uploader
    attr_accessor :content_source
    attr_reader :attempt, :folder_identifier, :response, :submission

    # @param folder_identifier [String] the upload location; @see ClaimsEvidenceApi::FolderIdentifier
    # @param content_source [String] the metadata source value for the upload
    def initialize(folder_identifier, content_source: 'va.gov')
      @content_source = content_source
      @service = ClaimsEvidenceApi::Service::Files.new
      self.folder_identifier = folder_identifier
    end

    # change the folder_identifier being uploaded to
    # @see ClaimsEvidenceApi::FolderIdentifier
    def folder_identifier=(folder_identifier)
      @service.folder_identifier = @folder_identifier = folder_identifier
    end

    # upload a file (unmodified) for a claim or persistent_attachment
    # this will track the file using the record identified by [saved_claim_id, persistent_attachment_id, form_id]
    #
    # @param file_path [String] path of the file to upload
    # @param form_id [String] the form_id of the claim
    # @param saved_claim_id [Integer] the db id for the claim
    # @param persistent_attachment_id [Integer] the db id for the attachment; default nil
    # @param doctype [Integer] the document type for the file; default 10
    # @param timestamp [DateTime] the date-va-received-document; default Time.zone.now
    #
    # @return [String] the file_uuid
    # rubocop:disable Metrics/ParameterLists
    def upload_file(file_path, form_id, saved_claim_id, persistent_attachment_id = nil, doctype = 10,
                    timestamp = Time.zone.now)
      context = { saved_claim_id:, persistent_attachment_id:, file_path: }
      monitor.track_upload_begun(**context)
      @submission = ClaimsEvidenceApi::Submission.find_or_create_by(saved_claim_id:, persistent_attachment_id:,
                                                                    form_id:)
      submission.folder_identifier = @service.folder_identifier
      submission.save

      @attempt = submission.submission_attempts.create
      attempt.metadata = provider_data = {
        contentSource: content_source,
        dateVaReceivedDocument: timestamp,
        documentTypeId: doctype
      }
      attempt.save

      monitor.track_upload_attempt(**context)
      @response = @service.upload(file_path, provider_data:)
      update_tracking

      monitor.track_upload_success(**context)
      submission.file_uuid
    rescue => e
      monitor.track_upload_failure(e.message, **context)
      raise e
    end
    # rubocop:enable Metrics/ParameterLists

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
      claim = upload_evidence_pdf(saved_claim_id, nil, nil, claim_stamp_set)
      file_uuid = submission.file_uuid

      claim.persistent_attachments.each { |pa| upload_evidence_pdf(saved_claim_id, pa.id, nil, attachment_stamp_set) }
      # submission and file_uuid will be for the last uploaded attachment when done

      file_uuid
    end

    # upload an evidence generated pdf
    # if `file_path` is provided it will be used instead of calling `to_pdf` on the evidence
    # providing `stamp_set` will perform stamping of the generated pdf
    #
    # @see PDFUtilities::PDFStamper
    #
    # @param saved_claim_id [Integer] the db id for the SavedClaim
    # @param persistent_attachment_id [Integer] the db id for the PersistentAttachment
    # @param file_path [String] file path of the pdf to upload
    # @param stamp_set [String|Array<Hash>] the identifier for a stamp set or an array of stamps
    #
    # @return [String] the file_uuid
    def upload_evidence_pdf(saved_claim_id, persistent_attachment_id = nil, file_path = nil, stamp_set = nil)
      context = { saved_claim_id:, persistent_attachment_id:, file_path:, stamp_set: }
      monitor.track_upload_begun(**context)

      claim = SavedClaim.find(saved_claim_id)
      pa = PersistentAttachment.find_by(id: persistent_attachment_id, saved_claim_id:) if persistent_attachment_id
      evidence = pa || claim
      context[:form_id] = claim.form_id
      context[:document_type] = evidence.document_type

      file_path ||= evidence.to_pdf
      file_path = PDFUtilities::PDFStamper.new(stamp_set).run(file_path, timestamp: evidence.created_at) if stamp_set
      context[:file_path] = file_path

      init_tracking(claim, persistent_attachment_id)

      monitor.track_upload_attempt(**context)
      perform_upload(evidence, file_path)

      update_tracking
      monitor.track_upload_success(**context)

      claim
    rescue => e
      monitor.track_upload_failure(e.message, **context)
      raise e
    end

    private

    # instantiate the uploader monitor
    # @see ClaimsEvidenceApi::Monitor::Uploader
    def monitor
      @monitor ||= ClaimsEvidenceApi::Monitor::Uploader.new
    end

    # create/retrieve the submission record for the claim and attachment
    # and create a new submission_attempt
    #
    # @param saved_claim [SavedClaim] the claim to be submitted
    # @param persistent_attachment_id [Integer] the db id for the attachment
    #
    # @return [ClaimsEvidenceApi::SubmissionAttempt]
    def init_tracking(saved_claim, persistent_attachment_id = nil)
      @submission = ClaimsEvidenceApi::Submission.find_or_create_by(saved_claim:, persistent_attachment_id:,
                                                                    form_id: saved_claim.form_id)
      # TODO: handle when submission already has a different identifier
      # https://github.com/department-of-veterans-affairs/va.gov-team/issues/114773
      submission.folder_identifier = @service.folder_identifier
      submission.save

      @attempt = submission.submission_attempts.create
    end

    # upload the claim evidence pdf
    # if `file_path` is provided it will be used instead of calling `to_pdf` on the claim
    # assembles the required metadata for the upload from the evidence object and updates the `attempt`
    #
    # @param evidence [SavedClaim|PersistentAttachment] the claim evidence to be uploaded
    # @param file_path [String] file path of the pdf to upload
    def perform_upload(evidence, file_path)
      attempt.metadata = provider_data = {
        contentSource: content_source,
        dateVaReceivedDocument: evidence.created_at,
        documentTypeId: evidence.document_type
      }
      attempt.save

      @response = @service.upload(file_path, provider_data:)
    rescue => e
      attempt.status = 'failure'
      attempt.error_message = e.body || e.message
      attempt.save

      raise e
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
  end

  # end ClaimsEvidenceApi
end
