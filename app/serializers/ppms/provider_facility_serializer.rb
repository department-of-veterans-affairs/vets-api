# frozen_string_literal: true

class PPMS::ProviderFacilitySerializer
  include FastJsonapi::ObjectSerializer

  has_many :providers, serializer: PPMS::ProviderSerializer
  has_many :facilities, serializer: Lighthouse::Facilities::FacilitySerializer
end
