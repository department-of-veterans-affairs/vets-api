# frozen_string_literal: true

class VAFacilitySerializer < ActiveModel::Serializer
  type 'va_facilities'

  def id
    "#{object.facility_type_prefix}_#{object.unique_id}"
  end

  def operating_status
    if Flipper.enabled?(:facility_locator_pull_operating_status_from_lighthouse)
      Lighthouse::Facilities::Client.new.get_by_id(id)&.operating_status
    end
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
