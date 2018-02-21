# frozen_string_literal: true

class ReceiveApplicationSerializer < ActiveModel::Serializer
  def id
    object.receive_application_id
  end

  attribute :receive_application_id
  attribute :tracking_number
  attribute :return_code
  attribute :application_uuid
  attribute :return_description
  attribute :submitted_at
end
