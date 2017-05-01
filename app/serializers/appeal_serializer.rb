# frozen_string_literal: true
class AppealSerializer < ActiveModel::Serializer
  attribute :id
  attribute :active
  attribute :decision_url
  attribute :status_message
  attribute :issues
  attribute :soc_released_on
  attribute :soc_url
  attribute :hearing
end
