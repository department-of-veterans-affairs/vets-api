# frozen_string_literal: true

class InProgressForm < ApplicationRecord
  class CleanUUID < ActiveRecord::Type::String
    def cast(value)
      super(value.to_s.delete('-'))
    end

    alias serialize cast
  end

  RETURN_URL_SQL = "CAST(metadata -> 'return_url' AS text)"
  scope :has_attempted_submit, -> { where("(metadata -> 'submission' ->> 'has_attempted_submit')::boolean") }
  scope :has_errors,           -> { where("(metadata -> 'submission' -> 'errors') IS NOT NULL") }
  scope :has_no_errors,        -> { where.not("(metadata -> 'submission' -> 'errors') IS NOT NULL") }
  scope :has_error_message,    -> { where("(metadata -> 'submission' -> 'error_message')::text !='false'") }
  # the double quotes in return_url are part of the value
  scope :return_url, ->(url) { where(%( #{RETURN_URL_SQL} = ? ), '"' + url + '"') }

  attribute :user_uuid, CleanUUID.new
  attr_encrypted :form_data, key: Settings.db_encryption_key
  validates(:form_data, presence: true)
  validates(:user_uuid, presence: true)
  validate(:id_me_user_uuid)
  before_save :serialize_form_data
  before_save :set_expires_at

  def self.form_for_user(form_id, user)
    InProgressForm.find_by(form_id: form_id, user_uuid: user.uuid)
  end

  def data_and_metadata
    {
      form_data: JSON.parse(form_data),
      metadata: metadata
    }
  end

  def metadata
    data = super || {}
    last_accessed = updated_at || Time.current
    data.merge(
      'expires_at' => expires_at.to_i || (last_accessed + expires_after).to_i,
      'last_updated' => updated_at.to_i,
      'in_progress_form_id' => id
    )
  end

  ##
  # Determines an expiration duration based on the UI form_id.
  # If the in_progress_form_custom_expiration feature is enabled,
  # the method can additionally return custom expiration durations whose values
  # are passed in as Strings from the UI.
  #
  # @return [ActiveSupport::Duration] an instance of ActiveSupport::Duration
  #
  def expires_after
    @expires_after ||=
      if Flipper.enabled?(:in_progress_form_custom_expiration)
        custom_expires_after
      else
        default_expires_after
      end
  end

  private

  # Some IDs we get from ID.me are 20, 21, 22 or 23 char hex strings
  # > we started off with just 22 random hex chars (from openssl random bytes) years
  # > ago, and switched to UUID v4 (minus dashes) later on
  # https://dsva.slack.com/archives/C1A7KLZ9B/p1501856503336861
  def id_me_user_uuid
    if user_uuid && !user_uuid.length.in?([20, 21, 22, 23, 32])
      errors[:user_uuid] << "(#{user_uuid}) is not a proper length"
    end
  end

  def serialize_form_data
    self.form_data = form_data.to_json unless form_data.is_a?(String)
  end

  def set_expires_at
    self.expires_at = Time.current + expires_after
  end

  def days_till_expires
    @days_till_expires ||= JSON.parse(form_data)['days_till_expires']
  end

  def default_expires_after
    case form_id
    when '21-526EZ'
      1.year
    else
      60.days
    end
  end

  def custom_expires_after
    options = { form_id: form_id, days_till_expires: days_till_expires }

    FormDurations::Worker.build(options).get_duration
  end
end
