# frozen_string_literal: true
require 'evss/claims_service'
require 'evss/documents_service'
require 'evss/auth_headers'

class EVSSClaimService
  include SentryLogging
  EVSS_CLAIM_KEYS = %w(open_claims historical_claims).freeze
  EVSS_COMMON_CLIENT_KEY = 'evss_common_client'.freeze

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
    return claims, true
  rescue Faraday::Error::TimeoutError, Breakers::OutageException => e
    log_error(e)
    return claims_scope.all, false
  end

  def update_from_remote(claim)
    begin
      raw_claim = client.find_claim_by_id(claim.evss_id).body.fetch('claim', {})
      claim.update_attributes(data: raw_claim)
      successful_sync = true
    rescue Faraday::Error::TimeoutError, Breakers::OutageException => e
      log_error(e)
      successful_sync = false
    end
    [claim, successful_sync]
  end

  def request_decision(claim)
    if @user.can_access_evss_common_client?
      EVSS::NewRequestDecision.perform_async(@user.uuid, claim.evss_id)
    else
      EVSS::RequestDecision.perform_async(auth_headers, claim.evss_id)
    end
  end

  # upload file to s3 and enqueue job to upload to EVSS
  def upload_document(evss_claim_document)
    uploader = EVSSClaimDocumentUploader.new(@user.uuid, evss_claim_document.tracked_item_id)
    uploader.store!(evss_claim_document.file_obj)
    # the uploader sanitizes the filename before storing, so set our doc to match
    evss_claim_document.file_name = uploader.final_filename
    EVSS::DocumentUpload.perform_async(auth_headers, @user.uuid, evss_claim_document.to_serializable_hash)
  end

  private

  def client
    @client ||= lambda do
      if @user.can_access_evss_common_client?
        EVSS::Claims::Service.new(@user)
      else
        EVSS::ClaimsService.new(auth_headers)
      end
    end.call
  end

  def auth_headers
    @auth_headers ||= EVSS::AuthHeaders.new(@user).to_h
  end

  def claims_scope
    EVSSClaim.for_user(@user)
  end

  def create_or_update_claim(raw_claim)
    claim = claims_scope.where(evss_id: raw_claim['id']).first_or_initialize(data: {})
    claim.update_attributes(list_data: raw_claim)
    claim
  end

  def log_error(exception)
    log_exception_to_sentry(exception, {}, backend_service: :evss)
  end
end
