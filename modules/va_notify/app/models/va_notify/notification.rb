# frozen_string_literal: true

module VANotify
  class Notification < ApplicationRecord
    self.table_name = 'va_notify_notifications'
    serialize :to, coder: JsonMarshal::Marshaller

    has_kms_key
    has_encrypted :to, key: :kms_key, **lockbox_options
  end
end
