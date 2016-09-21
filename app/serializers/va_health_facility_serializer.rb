# frozen_string_literal: true
class VAHealthFacilitySerializer < ActiveModel::Serializer
  attributes :id, :visn_id, :name, :classification, :lat, :long,
             :address, :phone, :hours, :services
end
