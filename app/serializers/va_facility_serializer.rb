# frozen_string_literal: true

class VAFacilitySerializer < ActiveModel::Serializer
  type 'va_facilities'

  def id
    "#{object.facility_type_prefix}_#{object.unique_id}"
  end

  attributes  :access,
              :address,
              :classification,
              :facility_type,
              :feedback,
              :hours,
              :lat,
              :long,
              :name,
              :phone,
              :services,
              :unique_id,
              :website,
              :visn
end
