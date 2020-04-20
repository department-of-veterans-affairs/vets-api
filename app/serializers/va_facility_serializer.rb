# frozen_string_literal: true

class VAFacilitySerializer < ActiveModel::Serializer
  type 'va_facilities'

  def id
    "#{object.facility_type_prefix}_#{object.unique_id}"
  end


  def operating_notes
    nil
  end

  def operating_status
    nil
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
              :operating_status,
              :phone,
              :services,
              :unique_id,
              :visn,
              :website
end
