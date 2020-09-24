# frozen_string_literal: true

class AppealSerializer < ActiveModel::Serializer
  attribute :id
  attribute :active
  attribute :type
  attribute :prior_decision_date
  attribute :requested_hearing_type
  attribute :events
  attribute :hearings
end
