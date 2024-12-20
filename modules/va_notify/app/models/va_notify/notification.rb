# frozen_string_literal: true

module VANotify
  class Notification < ApplicationRecord
    self.table_name = 'va_notify_notifications'

    has_kms_key
    has_encrypted :to, migrating: true, key: :kms_key, **lockbox_options
  end
end
