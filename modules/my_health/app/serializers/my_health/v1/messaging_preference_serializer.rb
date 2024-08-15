# frozen_string_literal: true

module MyHealth
  module V1
    class MessagingPreferenceSerializer
      include JSONAPI::Serializer

      attributes :email_address, :frequency
    end
  end
end
