# frozen_string_literal: true

require 'evss/claims_service'
require 'evss/documents_service'
require 'evss/auth_headers'

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

    job_id = EVSS::DocumentUpload.perform_async(headers, @user.user_account_uuid,
                                                evss_claim_document.to_serializable_hash)

    record_evidence_submission(evss_claim_document.evss_claim_id, job_id, evss_claim_document.tracked_item_id)
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

  def record_evidence_submission(claim_id, job_id, tracked_item_id)
    user_account = UserAccount.find(@user.user_account_uuid)
    job_class = self.class
    upload_status = 'pending'
    evidence_submission = EvidenceSubmission.new(claim_id:,
                                                 tracked_item_id:,
                                                 job_id:,
                                                 job_class:,
                                                 upload_status:)
    evidence_submission.user_account = user_account
    evidence_submission.save!
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
