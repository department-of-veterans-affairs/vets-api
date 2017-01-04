# frozen_string_literal: true
require 'evss/claims_service'
require 'evss/documents_service'
require 'evss/auth_headers'

class DisabilityClaimService
  EVSS_CLAIM_KEYS = %w(open_claims historical_claims).freeze

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
    DisabilityClaim::RequestDecision.perform_async(auth_headers, claim.evss_id)
  end

  # upload file to s3 and enqueue job to upload to EVSS
  def upload_document(file, disability_claim_document)
    uploader = DisabilityClaimDocumentUploader.new(@user.uuid, disability_claim_document.tracked_item_id)
    uploader.store!(file)
    # the uploader sanitizes the filename before storing, so set our doc to match
    disability_claim_document.file_name = uploader.filename
    DisabilityClaim::DocumentUpload.perform_async(auth_headers, @user.uuid, disability_claim_document.to_h)
  end

  def rating_info
    client = EVSS::CommonService.new(auth_headers)
    body = client.find_rating_info(@user.participant_id).body.fetch('rating_record', {})
    DisabilityRating.new(body['disability_rating_record'])
  end

  private

  def client
    @client ||= EVSS::ClaimsService.new(auth_headers)
  end

  def auth_headers
    @auth_headers ||= EVSS::AuthHeaders.new(@user).to_h
  end

  def claims_scope
    DisabilityClaim.for_user(@user)
  end

  def create_or_update_claim(raw_claim)
    claim = claims_scope.where(evss_id: raw_claim['id']).first_or_initialize(data: {})
    claim.update_attributes(list_data: raw_claim)
    claim
  end

  def log_error(exception)
    Rails.logger.error "#{exception.message}."
    Rails.logger.error exception.backtrace.join("\n") unless exception.backtrace.nil?
  end
end
