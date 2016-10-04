# frozen_string_literal: true
require_dependency 'evss/claims_service'

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
  rescue Faraday::Error::TimeoutError, Timeout::Error => e
    log_error(e)
    claims_scope.all.map do |claim|
      claim.sync_failed = true
      claim
    end
  end

  def update_from_remote(claim)
    begin
      raw_claim = client.find_claim_by_id(claim.evss_id).body.fetch('claim', {})
      claim.update_attributes(data: raw_claim)
    rescue Faraday::Error::TimeoutError, Timeout::Error => e
      claim.sync_failed = true
      log_error(e)
    end
    claim
  end

  def request_decision(claim)
    client.submit_5103_waiver(claim.evss_id).body
  end

  def upload_document(claim, tempfile, tracked_item_id)
    document_client.upload(tempfile.original_filename, tempfile.read, claim.evss_id, tracked_item_id).body
  end

  private

  def client
    @client ||= EVSS::ClaimsService.new(@user)
  end

  def document_client
    @document_client ||= EVSS::DocumentsService.new(@user)
  end

  def claims_scope
    DisabilityClaim.for_user(@user)
  end

  def create_or_update_claim(raw_claim)
    claim = claims_scope.where(evss_id: raw_claim['id']).first_or_initialize(data: {})
    claim.update_attributes(data: claim.data.merge(raw_claim))
    claim
  end

  def log_error(exception)
    Rails.logger.error "#{exception.message}."
    Rails.logger.error exception.backtrace.join("\n") unless exception.backtrace.nil?
  end
end
