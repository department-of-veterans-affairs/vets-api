# frozen_string_literal: true
require 'common/models/base'
# Prescription Notification Preference Model
class PrescriptionPreference < Common::Base
  attribute :email_address, String
  attribute :rx_flag, Boolean
end
