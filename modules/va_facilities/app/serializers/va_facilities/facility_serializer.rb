# frozen_string_literal: true

require_dependency 'va_facilities/api_serialization'

module VaFacilities
  class FacilitySerializer < ActiveModel::Serializer
    include ApiSerialization

    type 'va_facilities'

    def id
      ApiSerialization.id(object)
    end

    attributes :name, :facility_type, :classification, :website, :lat, :long,
               :address, :phone, :hours, :services, :satisfaction, :wait_times,
               :mobile, :active_status

    def services
      ApiSerialization.services(object)
    end

    def satisfaction
      ApiSerialization.satisfaction(object)
    end

    def wait_times
      ApiSerialization.wait_times(object)
    end
  end
end
