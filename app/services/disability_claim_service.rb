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
        find_or_initialize_claim(raw_claim)
      end
    end.flatten
  rescue Faraday::Error::TimeoutError, Timeout::Error => e
    log_error(e)
    DisabilityClaim.where("data->>'participant_id' = ?", @user.participant_id)
  end

  def find_by_evss_id(id)
    raw_claim = client.find_claim_by_id(id).body.fetch('claim', {})
    find_or_initialize_claim(raw_claim)
  rescue Faraday::Error::TimeoutError, Timeout::Error => e
    log_error(e)
    DisabilityClaim.find_by(evss_id: id)
  end

  def request_decision(id)
    client.submit_5103_waiver(id).body
  end

  # upload file to s3 and enqueue job to upload to EVSS
  # TODO (AJM): Unique filename in s3 but preserve original filename when uploading to evss
  def upload_document(claim_id, tempfile, tracked_item_id)
    uploader = DisabilityClaimDocumentUploader.new
    uploader.store!(tempfile)
    DisabilityClaim::DocumentUpload.perform_later(tempfile.original_filename,
                                                  @user.vaafi_attrs, claim_id,
                                                  tracked_item_id)
  end

  private

  def client
    @client ||= EVSS::ClaimsService.new(@user)
  end

  def find_or_initialize_claim(raw_claim)
    claim = DisabilityClaim.where(evss_id: raw_claim['id']).first_or_initialize
    raw_claim['participant_id'] = @user.participant_id
    claim.update_attributes(data: raw_claim)
    claim
  end

  def log_error(exception)
    Rails.logger.error "#{exception.message}."
    Rails.logger.error exception.backtrace.join("\n") unless exception.backtrace.nil?
  end
end
