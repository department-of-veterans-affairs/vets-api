# frozen_string_literal: true

require 'json_marshal/marshaller'

class InProgressForm < ApplicationRecord
  belongs_to :user_account, dependent: nil, optional: true

  class CleanUUID < ActiveRecord::Type::String
    def cast(value)
      super(value.to_s.delete('-'))
    end

    alias serialize cast
  end

  attr_accessor :skip_exipry_update, :real_user_uuid

  RETURN_URL_SQL = "CAST(metadata -> 'returnUrl' AS text)"
  scope :has_attempted_submit, lambda {
                                 where("(metadata -> 'submission' ->> 'hasAttemptedSubmit')::boolean or "\
                                       "(metadata -> 'submission' ->> 'has_attempted_submit')::boolean")
                               }
  scope :has_errors,           -> { where("(metadata -> 'submission' -> 'errors') IS NOT NULL") }
  scope :has_no_errors,        -> { where.not("(metadata -> 'submission' -> 'errors') IS NOT NULL") }
  scope :has_error_message,    lambda {
                                 where("(metadata -> 'submission' -> 'errorMessage')::text !='false' or "\
                                       "(metadata -> 'submission' -> 'error_message')::text !='false' ")
                               }
  # the double quotes in return_url are part of the value
  scope :return_url, ->(url) { where(%( #{RETURN_URL_SQL} = ? ), "\"#{url}\"") }

  attribute :user_uuid, CleanUUID.new
  serialize :form_data, JsonMarshal::Marshaller
  has_kms_key
  has_encrypted :form_data, key: :kms_key, **lockbox_options
  validates(:form_data, presence: true)
  validates(:user_uuid, presence: true)
  validate(:id_me_user_uuid)
  before_save :serialize_form_data
  before_save :set_expires_at, unless: :skip_exipry_update
  after_save :log_hca_email_diff

  def self.form_for_user(form_id, user)
    user_uuid_form = InProgressForm.find_by(form_id:, user_uuid: user.uuid)
    user_account_form = InProgressForm.find_by(form_id:, user_account: user.user_account) if user.user_account
    user_uuid_form || user_account_form
  end

  def self.for_user(user)
    user_uuid_forms = InProgressForm.where(user_uuid: user.uuid)
    if user.user_account
      user_uuid_forms.or(InProgressForm.where(user_account: user.user_account))
    else
      user_uuid_forms
    end
  end

  def data_and_metadata
    {
      formData: JSON.parse(form_data),
      metadata:
    }
  end

  def metadata
    data = super || {}
    last_accessed = updated_at || Time.current
    data.merge(
      'expiresAt' => expires_at.to_i || (last_accessed + expires_after).to_i,
      'lastUpdated' => updated_at.to_i,
      'inProgressFormId' => id
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

  def log_hca_email_diff
    HCA::LogEmailDiffJob.perform_async(id, real_user_uuid) if form_id == '1010ez'
  end

  # Some IDs we get from ID.me are 20, 21, 22 or 23 char hex strings
  # > we started off with just 22 random hex chars (from openssl random bytes) years
  # > ago, and switched to UUID v4 (minus dashes) later on
  # https://dsva.slack.com/archives/C1A7KLZ9B/p1501856503336861
  def id_me_user_uuid
    if user_uuid && !user_uuid.length.in?([20, 21, 22, 23, 32])
      errors.add(:user_uuid, "(#{user_uuid}) is not a proper length")
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
    options = { form_id:, days_till_expires: }

    FormDurations::Worker.build(options).get_duration
  end
end
