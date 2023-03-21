# frozen_string_literal: true

module Mobile
  module V0
    class ImmunizationSerializer
      include JSONAPI::Serializer

      BASE_URL = "#{Settings.hostname}/mobile/v0/health/locations/".freeze

      attributes :cvx_code,
                 :date,
                 :dose_number,
                 :dose_series,
                 :group_name,
                 :manufacturer,
                 :note,
                 :reaction,
                 :short_description

      has_one :location, links: {
        related: lambda { |object|
          object.location_id.nil? ? nil : BASE_URL + object.location_id
        }
      }
    end
  end
end
