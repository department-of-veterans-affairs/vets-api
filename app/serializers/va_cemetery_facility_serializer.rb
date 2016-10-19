# frozen_string_literal: true
class VACemeteryFacilitySerializer < ActiveModel::Serializer
  def id
    object.station_number
  end

  attributes :station_number, :district, :name, :status, :lat, :long,
             :address, :mailing_address, :phone
end
