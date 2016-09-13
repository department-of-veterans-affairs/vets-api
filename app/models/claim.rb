# frozen_string_literal: true
require_dependency 'evss/claims_service'
require_dependency 'evss/documents_service'

class Claim < ActiveModelSerializers::Model
  attr_accessor :id

  EVSS_CLAIM_KEYS = %w(openClaims historicalClaims).freeze

  def self.fetch_all(headers)
    evss_client = EVSS::ClaimsService.new(headers)
    raw_claims = evss_client.claims.body
    EVSS_CLAIM_KEYS.each_with_object([]) do |key, claims|
      next unless raw_claims[key]
      claims << raw_claims[key].map do |raw_claim|
        attrs = {
          id: raw_claim['id']
        }
        Claim.new(attrs)
      end
    end.flatten
  end

  def self.request_decision(headers, claim_id)
    evss_client = EVSS::ClaimsService.new(headers)
    evss_client.submit_5103_waiver(claim_id).body
  end

  def self.upload_document(headers, file_name, file_body, claim_id, tracked_item_id)
    # Todo, instead of having a class method and passing claim_id,
    # get claim_id from the model
    evss_client = EVSS::DocumentsService.new(headers)
    evss_client.upload(file_name, file_body, claim_id, tracked_item_id).body
  end
end
