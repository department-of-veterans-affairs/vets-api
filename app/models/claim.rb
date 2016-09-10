# frozen_string_literal: true
require_dependency 'evss/claims_service'

class Claim < ActiveModelSerializers::Model
  attr_accessor :id, :date_filed, :min_est_date, :max_est_date, :tracked_items,
                :contention_list, :phase_dates, :open, :waiver_submitted

  EVSS_CLAIM_KEYS = %w(openClaims historicalClaims).freeze

  def self.fetch_all(headers)
    evss_client = EVSS::ClaimsService.new(headers)
    raw_claims = evss_client.claims.body
    EVSS_CLAIM_KEYS.each_with_object([]) do |key, claims|
      next unless raw_claims[key]
      claims << raw_claims[key].map do |raw_claim|
        Claim.from_json(raw_claim)
      end
    end.flatten
  end

  def self.request_decision(claim_id, headers)
    evss_client = EVSS::ClaimsService.new(headers)
    evss_client.submit_5103_waiver(claim_id).body
  end

  def self.find_by_id(claim_id, headers)
    evss_client = EVSS::ClaimsService.new(headers)
    raw_claim = evss_client.find_claim_by_id(claim_id).body.fetch('claim', {})
    Claim.from_json(raw_claim)
  end

  def self.from_json(attrs)
    Claim.new(
      id: attrs['id'],
      date_filed: attrs['date'],
      contention_list: attrs['contentionList'],
      min_est_date: attrs['minEstClaimDate'],
      max_est_date: attrs['maxEstClaimDate'],
      phase_dates: attrs['claimPhaseDates'],
      tracked_items: attrs['claimTrackedItems'],
      open: attrs['claimCompleteDate'].blank?,
      waiver_submitted: attrs['waiver5103Submitted']
    )
  end
end
