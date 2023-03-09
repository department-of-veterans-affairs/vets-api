# frozen_string_literal: true

require 'jsonapi/serializer'

module Mobile
  module V0
    class AppointmentPreferencesSerializer
      include JSONAPI::Serializer

      attributes :notification_frequency,
                 :email_allowed,
                 :email_address,
                 :text_msg_allowed
    end
  end
end
