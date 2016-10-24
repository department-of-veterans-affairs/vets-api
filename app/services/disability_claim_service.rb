# frozen_string_literal: true
require_dependency 'evss/claims_service'
require_dependency 'evss/documents_service'
require_dependency 'evss/auth_headers'

class DisabilityClaimService
  EVSS_CLAIM_KEYS = %w(openClaims historicalClaims).freeze

  def initialize(user)
    @user = user
  end

  def all
    raw_claims = client.all_claims.body
    EVSS_CLAIM_KEYS.each_with_object([]) do |key, claims|
      next unless raw_claims[key]
      claims << raw_claims[key].map do |raw_claim|
        create_or_update_claim(raw_claim)
      end
    end.flatten
  rescue Faraday::Error::TimeoutError, Breakers::OutageException => e
    log_error(e)
    claims_scope.all.map do |claim|
      claim.successful_sync = false
      claim
    end
  end

  def update_from_remote(claim)
    begin
      raw_claim = client.find_claim_by_id(claim.evss_id).body.fetch('claim', {})
      claim.update_attributes(data: raw_claim, successful_sync: true)
    rescue Faraday::Error::TimeoutError, Breakers::OutageException => e
      claim.successful_sync = false
      log_error(e)
    end
    claim
  end

  def request_decision(claim)
    client.submit_5103_waiver(claim.evss_id).body
  end

  # upload file to s3 and enqueue job to upload to EVSS
  def upload_document(claim, tempfile, tracked_item_id)
    uploader = DisabilityClaimDocumentUploader.new(@user.uuid, tracked_item_id)
    uploader.store!(tempfile)
    DisabilityClaim::DocumentUpload.perform_later(tempfile.original_filename,
                                                  auth_headers, @user.uuid,
                                                  claim.id, tracked_item_id)
  end

  private

  def client
    @client ||= EVSS::ClaimsService.new(auth_headers)
  end

  def document_client
    @document_client ||= EVSS::DocumentsService.new(auth_headers)
  end

  def auth_headers
    @auth_headers ||= EVSS::AuthHeaders.new(@user).to_h
  end

  def claims_scope
    DisabilityClaim.for_user(@user)
  end

  def create_or_update_claim(raw_claim)
    claim = claims_scope.where(evss_id: raw_claim['id']).first_or_initialize(data: {})
    claim.update_attributes(data: claim.data.merge(raw_claim), successful_sync: true)
    claim
  end

  def log_error(exception)
    Rails.logger.error "#{exception.message}."
    Rails.logger.error exception.backtrace.join("\n") unless exception.backtrace.nil?
  end
end
