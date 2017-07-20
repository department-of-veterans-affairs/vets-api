# frozen_string_literal: true
module Preneeds
  class DischargeTypeSerializer < ActiveModel::Serializer
    attribute :id

    attribute(:discharge_type_id) { object.id }
    attribute :description
  end
end
