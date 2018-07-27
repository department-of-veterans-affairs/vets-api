# frozen_string_literal: true

class GIBillFeedbackSerializer < ActiveModel::Serializer
  attribute(:guid)
  attribute(:state)
  attribute(:response)
end
