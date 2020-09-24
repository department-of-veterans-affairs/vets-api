# frozen_string_literal: true

require 'fast_jsonapi'

module VAOS
  module V0
    class PreferencesSerializer
      include FastJsonapi::ObjectSerializer

      attributes :notification_frequency,
                 :email_allowed,
                 :email_address,
                 :text_msg_allowed
    end
  end
end
