# frozen_string_literal: true
class InProgressForm < ActiveRecord::Base
  EXPIRES_AFTER = 60.days
  attr_encrypted :form_data, key: Settings.db_encryption_key
  validates(:form_data, presence: true)
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
    data.merge('expires_at' => (expires + EXPIRES_AFTER).to_i)
  end

  private

  def serialize_form_data
    self.form_data = form_data.to_json unless form_data.is_a?(String)
  end
end
