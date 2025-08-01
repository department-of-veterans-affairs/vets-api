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

    # @param folder_identifier [String] the upload location; @see ClaimsEvidenceApi::XFolderUri
    # @param content_source [String] the metadata source value for the upload
    def initialize(folder_identifier, content_source: 'va.gov')
      @content_source = content_source
      @service = ClaimsEvidenceApi::Service::Files.new
      self.folder_identifier = folder_identifier
    end

    # change the folder_identifier being uploaded to
    # @see ClaimsEvidenceApi::XFolderUri
    def folder_identifier=(folder_identifier)
      @service.x_folder_uri = @folder_identifier = folder_identifier
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
      @submission = ClaimsEvidenceApi::Submission.find_or_create_by(saved_claim_id:, persistent_attachment_id:,
                                                                    form_id:)
      submission.x_folder_uri = @service.x_folder_uri
      submission.save

      @attempt = submission.submission_attempts.create
      attempt.metadata = provider_data = {
        contentSource: content_source,
        dateVaReceivedDocument: timestamp,
        documentTypeId: doctype
      }
      attempt.save

      @response = @service.upload(file_path, provider_data:)
      update_tracking

      @submission.file_uuid
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
    def upload_saved_claim_evidence(saved_claim_id, claim_stamp_set = nil, attachment_stamp_set = nil)
      claim = upload_evidence_pdf(saved_claim_id, nil, nil, claim_stamp_set)
      claim.persistent_attachments.each { |pa| upload_evidence_pdf(saved_claim_id, pa.id, nil, attachment_stamp_set) }
    end

    # upload an evidence generated pdf
    # if `pdf_path` is provided it will be used instead of calling `to_pdf` on the evidence
    # providing `stamp_set` will perform stamping of the generated pdf
    #
    # @see PDFUtilities::PDFStamper
    #
    # @param saved_claim_id [Integer] the db id for the SavedClaim
    # @param pa_id [Integer] the db id for the PersistentAttachment
    # @param pdf_path [String] file path of the pdf to upload
    # @param stamp_set [String|Array<Hash>] the identifier for a stamp set or an array of stamps
    #
    # @return [SavedClaim] the claim referenced for evidence
    def upload_evidence_pdf(saved_claim_id, pa_id = nil, pdf_path = nil, stamp_set = nil)
      context = { saved_claim_id:, pa_id:, pdf_path:, stamp_set: }
      monitor.track_upload_begun(**context)

      claim = SavedClaim.find(saved_claim_id)
      pa = PersistentAttachment.find_by(id: pa_id, saved_claim_id:) if pa_id
      evidence = pa || claim
      context[:form_id] = claim.form_id
      context[:document_type] = evidence.document_type

      pdf_path ||= evidence.to_pdf
      pdf_path = PDFUtilities::PDFStamper.new(stamp_set).run(pdf_path, timestamp: evidence.created_at) if stamp_set
      context[:pdf_path] = pdf_path

      init_tracking(claim, pa_id)

      monitor.track_upload_attempt(**context)
      perform_upload(evidence, pdf_path)

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
      submission.x_folder_uri = @service.x_folder_uri
      submission.save

      @attempt = submission.submission_attempts.create
    end

    # upload the claim evidence pdf
    # if `pdf_path` is provided it will be used instead of calling `to_pdf` on the claim
    # assembles the required metadata for the upload from the evidence object and updates the `attempt`
    #
    # @param evidence [SavedClaim|PersistentAttachment] the claim evidence to be uploaded
    # @param pdf_path [String] file path of the pdf to upload
    def perform_upload(evidence, pdf_path)
      attempt.metadata = provider_data = {
        contentSource: content_source,
        dateVaReceivedDocument: evidence.created_at,
        documentTypeId: evidence.document_type
      }
      attempt.save

      @response = @service.upload(pdf_path, provider_data:)
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
