# frozen_string_literal: true

require 'common/models/base'
require 'evss/pciu/email_address'

# Secure Messaging Notification Preference Model
class MessagingPreference < Common::Base
  include ActiveModel::Validations

  FREQUENCY_UPDATE_MAP = {
    'none' => 0,
    'each_message' => 1,
    'daily' => 2
  }.freeze

  FREQUENCY_GET_MAP = {
    'None' => 'none',
    'Each message' => 'each_message',
    'Once daily' => 'daily'
  }.freeze

  attribute :email_address, String
  attribute :frequency, String
  validates :frequency, presence: true, inclusion: { in: FREQUENCY_UPDATE_MAP.keys }
  validates(
    :email_address,
    presence: true,
    format: { with: EVSS::PCIU::EmailAddress::VALID_EMAIL_REGEX },
    length: { maximum: 255, minimum: 6 }
  )

  def mhv_params
    raise Common::Exceptions::ValidationErrors, self unless valid?

    { email_address:, notify_me: FREQUENCY_UPDATE_MAP.fetch(frequency) }
  end

  def id
    Digest::SHA256.hexdigest(instance_variable_get(:@original_attributes).to_json)
  end
end
