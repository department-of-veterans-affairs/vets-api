# frozen_string_literal: true

class SecondaryAppealForm < ApplicationRecord
  validates :guid, :form_id, :form, presence: true

  belongs_to :appeal_submission

  has_kms_key
  has_encrypted :form, key: :kms_key, **lockbox_options
end
