# frozen_string_literal: true

class VAFacilitySerializer < ActiveModel::Serializer
  type 'va_facilities'

  def id
    "#{object.facility_type_prefix}_#{object.unique_id}"
  end

  attributes :unique_id, :name, :facility_type, :classification, :website, :lat, :long,
             :address, :phone, :hours, :services, :feedback, :access
end
