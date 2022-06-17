# frozen_string_literal: true

module VAOS
  module V2
    class ProvidersSerializer
      include FastJsonapi::ObjectSerializer

      set_id :provider_identifier

      set_type :providers

      attributes :provider_identifier,
                 :provider_identifier_type,
                 :name,
                 :provider_type,
                 :address,
                 :address_street,
                 :address_city,
                 :address_state_province,
                 :address_county
    end
  end
end
