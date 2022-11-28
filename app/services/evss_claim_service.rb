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
    EVSS::RequestDecision.perform_async(auth_headers, claim.evss_id)
  end

  # upload file to s3 and enqueue job to upload to EVSS, used by Claim Status Tool
  # EVSS::DocumentsService is where the uploading of documents actually happens
  def upload_document(evss_claim_document)
    uploader = EVSSClaimDocumentUploader.new(@user.uuid, evss_claim_document.uploader_ids)
    uploader.store!(evss_claim_document.file_obj)
    # the uploader sanitizes the filename before storing, so set our doc to match
    evss_claim_document.file_name = uploader.final_filename
    EVSS::DocumentUpload.perform_async(auth_headers, @user.uuid, evss_claim_document.to_serializable_hash)
  rescue CarrierWave::IntegrityError => e
    log_exception_to_sentry(e, nil, nil, 'warn')
    raise Common::Exceptions::UnprocessableEntity.new(detail: e.message,
                                                      source: 'EVSSClaimService.upload_document')
  end

  private

  def client
    @client ||= EVSS::ClaimsService.new(auth_headers)
  end

  def auth_headers
    @auth_headers ||= EVSS::AuthHeaders.new(@user).to_h
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
