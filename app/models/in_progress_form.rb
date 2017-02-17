# frozen_string_literal: true
class InProgressForm < ActiveRecord::Base
  attr_encrypted :form_data, key: ENV['DB_ENCRYPTION_KEY']

  def self.form_for_user(form_id, user)
    InProgressForm.where(form_id: form_id, user_uuid: user.uuid).take
  end
end
