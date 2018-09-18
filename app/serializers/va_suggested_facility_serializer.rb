# frozen_string_literal: true

class VASuggestedFacilitySerializer < ActiveModel::Serializer
  type 'va_facilities'

  def id
    "#{object.facility_type_prefix}_#{object.unique_id}"
  end

  attributes :name, :address
end
