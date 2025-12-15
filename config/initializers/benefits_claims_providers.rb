# frozen_string_literal: true

require 'benefits_claims/providers/provider_registry'
require 'benefits_claims/providers/lighthouse/lighthouse_benefits_claims_provider'

BenefitsClaims::Providers::ProviderRegistry.register(
  :lighthouse,
  BenefitsClaims::Providers::Lighthouse::LighthouseBenefitsClaimsProvider,
  feature_flag: 'benefits_claims_lighthouse_provider',
  enabled_by_default: false
)

# Future providers can be registered here:
# BenefitsClaims::Providers::ProviderRegistry.register(
#   :champva,
#   BenefitsClaims::Providers::Champva::ChampvaBenefitsClaimsProvider,
#   feature_flag: 'benefits_claims_champva_provider',
#   enabled_by_default: false
# )
