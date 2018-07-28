# frozen_string_literal: true

class GIBillFeedbackSerializer < ActiveModel::Serializer
  attribute(:guid)
  attribute(:state)
  attribute(:parsed_response)
end
