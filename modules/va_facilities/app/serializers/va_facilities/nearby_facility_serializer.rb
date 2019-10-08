# frozen_string_literal: true

require_dependency 'va_facilities/api_serialization_v1'

module VaFacilities
  class NearbyFacilitySerializer < ActiveModel::Serializer
    include ApiSerialization

    type 'va_facilities'

    def id
      ApiSerialization.id(object)
    end

    attribute :long, key: :lng
    attributes :name, :facility_type, :classification, :website, :lat,
               :address, :phone, :hours, :services, :satisfaction,
               :mobile, :active_status

    def services
      ApiSerializationV1.services(object)
    end

    def satisfaction
      ApiSerializationV1.satisfaction(object)
    end
  end
end
