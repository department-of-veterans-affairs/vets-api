# frozen_string_literal: true

class PPMS::ProviderFacilitySerializer
  include FastJsonapi::ObjectSerializer

  set_key_transform :camel_lower

  has_many :providers, serializer: PPMS::ProviderSerializer
  has_many :facilities, serializer: Lighthouse::Facilities::FacilitySerializer
end
