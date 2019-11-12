# frozen_string_literal: true

module VAOS
  class MessagesSerializer
    include FastJsonapi::ObjectSerializer

    set_id do |object|
      object.data_identifier[:unique_id]
    end

    set_type :messages
  end
end
