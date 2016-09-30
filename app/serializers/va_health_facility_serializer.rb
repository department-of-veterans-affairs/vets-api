# frozen_string_literal: true
class VAHealthFacilitySerializer < ActiveModel::Serializer
  def id
    object.station_number
  end

  attributes :station_id, :station_number, :visn_id, :name, :classification, :lat, :long,
             :address, :phone, :hours, :services
end
