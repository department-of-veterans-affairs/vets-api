# frozen_string_literal: true
class VAFacilitySerializer < ActiveModel::Serializer
  def id
    object.unique_id
  end

  attributes :unique_id, :name, :facility_type, :classification, :lat, :long,
             :address, :phone, :hours, :services
end
