# frozen_string_literal: true

class Form5655Submission < ApplicationRecord
  validates :user_uuid, presence: true
  has_kms_key
  has_encrypted :form_json, :metadata, key: :kms_key, **lockbox_options
  after_create :add_form_properties

  def form
    @form_hash ||= JSON.parse(form_json)
  end

  def submit_to_vba
    Form5655::VBASubmissionJob.perform_async(id, user_uuid)
  end

  def submit_to_vha
    Form5655::VHASubmissionJob.perform_async(id, user_uuid)
  end

  def add_form_properties
    form['transactionId'] = id
    form['timestamp'] = DateTime.now.strftime('%Y%m%dT%H%M%S')
    self.form_json = form.to_json

    save!
  end
end
