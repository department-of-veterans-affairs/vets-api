# frozen_string_literal: true

module VaFacilities
  class NearbySerializer < ActiveModel::Serializer
    BASE_PATH = '/services/va_facilities/v0'

    def id
      "vha_#{object.vha_facility_id}"
    end

    belongs_to :va_facilities do
      include_data false
      link(:related) { "#{BASE_PATH}/facilities/vha_#{object.vha_facility_id}" }
    end

    type('nearby_facility')
    attribute :min, key: :drivetime_band_min
    attribute :max, key: :drivetime_band_max
  end
end
