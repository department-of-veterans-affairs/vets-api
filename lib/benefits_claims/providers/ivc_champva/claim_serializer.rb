# frozen_string_literal: true

require 'benefits_claims/providers/lighthouse/claim_serializer'

module BenefitsClaims
  module Providers
    module IvcChampva
      module ClaimSerializer
        def self.to_json_api(dto)
          BenefitsClaims::Providers::Lighthouse::ClaimSerializer.to_json_api(dto)
        end
      end
    end
  end
end
