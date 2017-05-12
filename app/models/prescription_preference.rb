# frozen_string_literal: true
require 'common/models/base'
# Prescription Notification Preference Model
class PrescriptionPreference < Common::Base
  include ActiveModel::Validations

  attribute :email_address, String
  attribute :rx_flag, Boolean

  # Always validate that rx_flag is provided
  validates :rx_flag, presence: true, inclusion: { in: [true, false] }
  # Always require valid email address
  validates :email_address, presence: true, format: { with: /.+@.+\..+/i }
end
