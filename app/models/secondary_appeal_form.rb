# frozen_string_literal: true

class SecondaryAppealForm < ApplicationRecord
  validates :guid, presence: true
  validate(:form_matches_schema)
  validate(:form_must_be_string)
  
  belongs_to :appeal_submission

  has_kms_key
  has_encrypted :form, key: :kms_key, **lockbox_options

  private

  def form_is_string
    form.is_a?(String)
  end

  def form_must_be_string
    errors.add(:form, :invalid_format, message: 'must be a json string') unless form_is_string
  end

  def form_matches_schema
    
  end
end
