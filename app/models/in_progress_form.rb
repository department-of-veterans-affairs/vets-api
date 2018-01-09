# frozen_string_literal: true

class InProgressForm < ActiveRecord::Base
  class CleanUUID < ActiveRecord::Type::String
    def type_cast_for_database(value)
      value.to_s.delete('-')
    end

    alias type_cast type_cast_for_database
  end

  EXPIRES_AFTER = 60.days
  attribute :user_uuid, CleanUUID.new
  attr_encrypted :form_data, key: Settings.db_encryption_key
  validates(:form_data, presence: true)
  validates(:user_uuid, presence: true)
  validate(:id_me_user_uuid)
  before_save :serialize_form_data

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
    expires = updated_at || Time.current
    data.merge(
      'expires_at' => (expires + EXPIRES_AFTER).to_i,
      'last_updated' => updated_at.to_i
    )
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
end
