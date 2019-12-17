# frozen_string_literal: true

module VAOS
  class MessagesSerializer
    include FastJsonapi::ObjectSerializer

    set_id do |object|
      object.data_identifier[:unique_id]
    end

    set_type :messages

    attributes :message_text,
               :message_date_time,
               :sender_id,
               :appointment_request_id,
               :date
  end
end
