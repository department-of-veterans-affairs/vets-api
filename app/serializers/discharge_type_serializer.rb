# frozen_string_literal: true

class DischargeTypeSerializer < ActiveModel::Serializer
  attribute :id

  attribute(:discharge_type_id) { object.id }
  attribute :description
end
