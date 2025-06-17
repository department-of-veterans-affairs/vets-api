# frozen_string_literal: true

require 'evss/claims_service'
require 'evss/documents_service'
require 'evss/auth_headers'
require 'lighthouse/benefits_documents/constants'
require 'lighthouse/benefits_documents/utilities/helpers'

# EVSS Claims Status Tool
class EVSSClaimService
  include SentryLogging
  EVSS_CLAIM_KEYS = %w[open_claims historical_claims].freeze

  def initialize(user)
    @user = user
  end

  def all
    raw_claims = client.all_claims.body
    claims = EVSS_CLAIM_KEYS.each_with_object([]) do |key, claim_accum|
      next unless raw_claims[key]

      claim_accum << raw_claims[key].map do |raw_claim|
        create_or_update_claim(raw_claim)
      end
    end.flatten
    [claims, true]
  rescue Breakers::OutageException, EVSS::ErrorMiddleware::EVSSBackendServiceError
    [claims_scope.all, false]
  end

  def update_from_remote(claim)
    begin
      raw_claim = client.find_claim_by_id(claim.evss_id).body.fetch('claim', {})
      claim.update(data: raw_claim)
      successful_sync = true
    rescue Breakers::OutageException, EVSS::ErrorMiddleware::EVSSBackendServiceError
      successful_sync = false
    end
    [claim, successful_sync]
  end

  def request_decision(claim)
    # Workaround for non-Veteran users
    headers = auth_headers.clone
    headers_supplemented = supplement_auth_headers(claim.evss_id, headers)

    job_id = EVSS::RequestDecision.perform_async(headers, claim.evss_id)

    record_workaround('request_decision', claim.evss_id, job_id) if headers_supplemented

    job_id
  end

  # upload file to s3 and enqueue job to upload to EVSS, used by Claim Status Tool
  # EVSS::DocumentsService is where the uploading of documents actually happens
  def upload_document(evss_claim_document)
    uploader = EVSSClaimDocumentUploader.new(@user.user_account_uuid, evss_claim_document.uploader_ids)
    uploader.store!(evss_claim_document.file_obj)

    # the uploader sanitizes the filename before storing, so set our doc to match
    evss_claim_document.file_name = uploader.final_filename

    # Workaround for non-Veteran users
    headers = auth_headers.clone
    headers_supplemented = supplement_auth_headers(evss_claim_document.evss_claim_id, headers)

    evidence_submission_id = nil
    if Flipper.enabled?(:cst_send_evidence_submission_failure_emails)
      evidence_submission_id = create_initial_evidence_submission(evss_claim_document).id
    end
    job_id = EVSS::DocumentUpload.perform_async(headers, @user.user_account_uuid,
                                                evss_claim_document.to_serializable_hash, evidence_submission_id)
    record_workaround('document_upload', evss_claim_document.evss_claim_id, job_id) if headers_supplemented

    job_id
  rescue CarrierWave::IntegrityError => e
    log_exception_to_sentry(e, nil, nil, 'warn')
    raise Common::Exceptions::UnprocessableEntity.new(
      detail: e.message, source: 'EVSSClaimService.upload_document'
    )
  end

  private

  def bgs_service
    @bgs ||= BGS::Services.new(external_uid: @user.participant_id,
                               external_key: @user.participant_id)
  end

  def get_claim(claim_id)
    bgs_service.ebenefits_benefit_claims_status.find_benefit_claim_details_by_benefit_claim_id(
      benefit_claim_id: claim_id
    )
  end

  def client
    @client ||= EVSS::ClaimsService.new(auth_headers)
  end

  def auth_headers
    @auth_headers ||= EVSS::AuthHeaders.new(@user).to_h
  end

  def supplement_auth_headers(claim_id, headers)
    # Assuming this header has a value of "", we want to get the Veteran
    # associated with the claims' participant ID. We can get this by fetching
    # the claim details from BGS and looking at the Participant ID of the
    # Veteran associated with the claim
    blank_header = headers['va_eauth_birlsfilenumber'].blank?
    if blank_header
      claim = get_claim(claim_id)
      veteran_participant_id = claim[:benefit_claim_details_dto][:ptcpnt_vet_id]
      headers['va_eauth_pid'] = veteran_participant_id
      # va_eauth_pnid maps to the users SSN. Using this here so that the header
      # has a value
      headers['va_eauth_birlsfilenumber'] = headers['va_eauth_pnid']
    end

    blank_header
  end

  def record_workaround(task, claim_id, job_id)
    ::Rails.logger.info('Supplementing EVSS headers', {
                          message_type: "evss.#{task}.no_birls_id",
                          claim_id:,
                          job_id:,
                          revision: 2
                        })
  end

  def create_initial_evidence_submission(document)
    user_account = UserAccount.find(@user.user_account_uuid)
    es = EvidenceSubmission.create(
      claim_id: document.evss_claim_id,
      tracked_item_id: document.tracked_item_id,
      upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:CREATED],
      user_account:,
      template_metadata: { personalisation: create_personalisation(document) }.to_json
    )
    StatsD.increment('cst.evss.document_uploads.evidence_submission_record_created')
    ::Rails.logger.info('EVSS - Created Evidence Submission Record', {
                          claim_id: document.evss_claim_id,
                          evidence_submission_id: es.id
                        })
    es
  end

  def create_personalisation(document)
    first_name = auth_headers['va_eauth_firstName'].titleize unless auth_headers['va_eauth_firstName'].nil?
    { first_name:,
      document_type: document.description,
      file_name: document.file_name,
      obfuscated_file_name: BenefitsDocuments::Utilities::Helpers.generate_obscured_file_name(document.file_name),
      date_submitted: BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(Time.zone.now),
      date_failed: nil }
  end

  def claims_scope
    EVSSClaim.for_user(@user)
  end

  def create_or_update_claim(raw_claim)
    claim = claims_scope.where(evss_id: raw_claim['id']).first
    if claim.blank?
      claim = EVSSClaim.new(user_uuid: @user.uuid,
                            user_account: @user.user_account,
                            evss_id: raw_claim['id'],
                            data: {})
    end
    claim.update(list_data: raw_claim)
    claim
  end
end
