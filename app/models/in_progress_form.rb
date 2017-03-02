# frozen_string_literal: true
class InProgressForm < ActiveRecord::Base
  attr_encrypted :form_data, key: Settings.db_encryption_key

  def self.form_for_user(form_id, user)
    InProgressForm.find_by(form_id: form_id, user_uuid: user.uuid)
  end
end
