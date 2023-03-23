# frozen_string_literal: true

# VAOS V2 serializer not in use
# :nocov:
module VAOS
  module V2
    class ProvidersSerializer
      include JSONAPI::Serializer

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
# :nocov:
