# frozen_string_literal: true

class VAFacilityNameSerializer < ActiveModel::Serializer
  attributes :name, :address

  def id
    "#{PREFIX_MAP[object.facility_type]}_#{object.unique_id}"
  end
end
