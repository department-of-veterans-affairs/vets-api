# frozen_string_literal: true

require 'disability_compensation/responses/claims_service_response'
require 'lighthouse/benefits_claims/service'

class LighthouseClaimsServiceProvider
  include ClaimsServiceProvider

  def initialize(icn)
    @service = BenefitsClaims::Service.new(icn)
  end

  def all_claims(lighthouse_client_id = nil, lighthouse_rsa_key_path = nil)
    # the below call to get_claims only gets potential OPEN claims
    data = @service.get_claims(lighthouse_client_id, lighthouse_rsa_key_path)['data']
    transform(data)
  end

  private

  def transform(data)
    open_claims = data.map do |open_claim|
      DisabilityCompensation::ApiProvider::Claim.new(
        id: open_claim['id'],
        base_end_product_code: open_claim['attributes']['baseEndProductCode'],
        claim_date: open_claim['attributes']['claimDate'],
        claim_phase_dates: open_claim['attributes']['claimPhaseDates'],
        development_letter_sent: open_claim['attributes']['developmentLetterSent'],
        status: open_claim['attributes']['status'] # make sure words/strings syntax is perfect match
      )
    end

    DisabilityCompensation::ApiProvider::ClaimsServiceResponse.new(open_claims:)
  end
end
