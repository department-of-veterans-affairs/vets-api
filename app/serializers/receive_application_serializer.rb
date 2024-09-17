# frozen_string_literal: true

class ReceiveApplicationSerializer
  include JSONAPI::Serializer

  set_id :receive_application_id
  set_type :preneeds_receive_applications

  attribute :receive_application_id
  attribute :tracking_number
  attribute :return_code
  attribute :application_uuid
  attribute :return_description
  attribute :submitted_at
end
