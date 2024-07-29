# frozen_string_literal: true

class MessagingPreferenceSerializer
  include JSONAPI::Serializer

  attributes :email_address, :frequency
end
