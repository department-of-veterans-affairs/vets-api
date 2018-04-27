# frozen_string_literal: true

require 'common/models/base'
# Prescription Notification Preference Model
class PrescriptionPreference < Common::Base
  include ActiveModel::Validations

  attribute :email_address, String
  attribute :rx_flag, Boolean

  validates :rx_flag, inclusion: { in: [true, false] }
  validates(
    :email_address,
    presence: true,
    format: { with: EVSS::PCIU::EmailAddress::VALID_EMAIL_REGEX },
    length: { maximum: 255, minimum: 6 }
  )

  def mhv_params
    raise Common::Exceptions::ValidationErrors, self unless valid?
    { email_address: email_address, rx_flag: rx_flag }
  end

  def id
    Digest::SHA256.hexdigest(instance_variable_get(:@original_attributes).to_json)
  end
end
