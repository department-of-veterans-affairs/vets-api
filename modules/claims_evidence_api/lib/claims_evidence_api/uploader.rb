# frozen_string_literal: true

require 'claims_evidence_api/exceptions'
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

    # upload claim and evidence pdfs
    # providing the `X_stamp_set` will perform stamping of the generated pdf
    #
    # @see PDFUtilities::PDFStamper
    #
    # @param saved_claim_id [Integer] the db id for the claim
    # @param claim_stamp_set [String|Array<Hash>] the identifier for a stamp set or an array of stamps
    # @param attachment_stamp_set [String|Array<Hash>] the identifier for a stamp set or an array of stamps
    def upload_saved_claim_evidence(saved_claim_id, claim_stamp_set = nil, attachment_stamp_set = nil)
      claim = upload_saved_claim_pdf(saved_claim_id, nil, claim_stamp_set)
      claim.persistent_attachments.each { |pa| upload_attachment_pdf(saved_claim_id, pa.id, nil, attachment_stamp_set) }
    end

    # upload a saved_claim generated pdf
    # if `pdf_path` is provided it will be used instead of calling `to_pdf` on the claim
    #
    # @param saved_claim_id [Integer] the db id for the claim
    # @param pdf_path [String] file path of the pdf to upload
    # @param stamp_set [String|Array<Hash>] the identifier for a stamp set or an array of stamps
    #
    # @return [SavedClaim] the claim uploaded
    def upload_saved_claim_pdf(saved_claim_id, pdf_path = nil, stamp_set = nil)
      claim = SavedClaim.find(saved_claim_id)
      init_tracking(claim)
      perform_upload(claim, pdf_path, stamp_set)
      update_tracking

      claim
    end

    # upload a claim evidence (persistent_attachment) pdf
    # if `pdf_path` is provided it will be used instead of calling `to_pdf` on the claim
    #
    # @param saved_claim_id [Integer] the db id for the claim
    # @param attachment_id [Integer] the db id for the attachment
    # @param pdf_path [String] file path of the pdf to upload
    # @param stamp_set [String|Array<Hash>] the identifier for a stamp set or an array of stamps
    #
    # @return [PersistentAttachment] the attachment uploaded
    def upload_attachment_pdf(saved_claim_id, attachment_id, pdf_path = nil, stamp_set = nil)
      claim = SavedClaim.find(saved_claim_id)
      pa = PersistentAttachment.find_by(id: attachment_id, saved_claim_id:)
      init_tracking(claim, pa.id)
      perform_upload(pa, pdf_path, stamp_set)
      update_tracking

      pa
    end

    private

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
    # @param stamp_set [String|Array<Hash>] the identifier for a stamp set or an array of stamps
    def perform_upload(evidence, pdf_path = nil, stamp_set = nil)
      pdf_path ||= evidence.to_pdf
      pdf_path = PDFUtilities::PDFStamper.new(stamp_set).run(pdf_path, timestamp: evidence.created_at) if stamp_set
      submission.update_reference_data(pdf_path:)

      attempt.metadata = provider_data = {
        contentSource: content_source,
        dateVaReceivedDocument: evidence.created_at,
        documentTypeId: evidence.document_type
      }
      attempt.save

      @response = @service.upload(pdf_path, provider_data:)
    end

    # update the tracking records with the result of the attempt
    # @raise [ClaimsEvidenceApi::Exceptions::VefsError] if upload is not successful
    def update_tracking
      unless response.success?
        attempt.status = 'failure'
        attempt.error_message = response.body
        attempt.save

        error_key = response.body.dig('messages', 0, 'key') || response.body['code']
        error_msg = response.body.dig('messages', 0, 'text') || response.body['message']
        raise ClaimsEvidenceApi::Exceptions::VefsError, "#{error_key} - #{error_msg}"
      end

      submission.file_uuid = response.body['uuid']
      submission.save

      attempt.status = 'accepted'
      attempt.response = response.body
      attempt.save

      response
    end
  end

  # end ClaimsEvidenceApi
end
