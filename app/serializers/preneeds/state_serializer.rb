# frozen_string_literal: true
module Preneeds
  class StateSerializer < ActiveModel::Serializer
    attribute :id

    attribute(:preneeds_state_id) { object.id }
    attribute :code
    attribute :first_five_zip
    attribute :last_five_zip
    attribute :lower_indicator
    attribute :name
  end
end
