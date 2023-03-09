# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
require 'jsonapi/serializer'

module VAOS
  module V0
    class PreferencesSerializer
      include JSONAPI::Serializer

      attributes :notification_frequency,
                 :email_allowed,
                 :email_address,
                 :text_msg_allowed
    end
  end
end
# :nocov:
