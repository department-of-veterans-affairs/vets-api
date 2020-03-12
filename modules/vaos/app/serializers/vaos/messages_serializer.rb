# frozen_string_literal: true

module VAOS
  class MessagesSerializer
    include FastJsonapi::ObjectSerializer

    set_id do |object|
      object.data_identifier[:unique_id]
    end

    set_type :messages

    attributes :message_text, :message_date_time, :appointment_request_id, :date
    attribute :sender_id, if: proc { |object| object.try(:sender_id).present? }
  end
end
