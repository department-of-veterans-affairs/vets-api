# frozen_string_literal: true

class Form5655Submission < ApplicationRecord
  validates :user_uuid, presence: true
  has_kms_key
  has_encrypted :form_json, :metadata, key: :kms_key, **lockbox_options

  def form
    @form_hash ||= JSON.parse(form_json)
  end
end
