# frozen_string_literal: true

require 'benefits_claims/providers/provider_registry'
require 'benefits_claims/providers/lighthouse/lighthouse_benefits_claims_provider'
require 'benefits_claims/providers/ivc_champva/ivc_champva_benefits_claims_provider'

BenefitsClaims::Providers::ProviderRegistry.register(
  :lighthouse,
  BenefitsClaims::Providers::Lighthouse::LighthouseBenefitsClaimsProvider,
  feature_flag: 'benefits_claims_lighthouse_provider',
  enabled_by_default: false
)

BenefitsClaims::Providers::ProviderRegistry.register(
  :ivc_champva,
  BenefitsClaims::Providers::IvcChampva::IvcChampvaBenefitsClaimsProvider,
  feature_flag: 'benefits_claims_ivc_champva_provider',
  enabled_by_default: false
)
