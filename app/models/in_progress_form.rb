# frozen_string_literal: true
class InProgressForm < ActiveRecord::Base
  attr_encrypted :form_data, key: Settings.db_encryption_key
  validates(:form_data, presence: true)
  before_save :serialize_form_data

  def self.form_for_user(form_id, user)
    InProgressForm.find_by(form_id: form_id, user_uuid: user.uuid)
  end

  private

  def serialize_form_data
    self.form_data = form_data.to_json unless form_data.is_a?(String)
  end
end
