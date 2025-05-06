# frozen_string_literal: true

class SecondaryAppealForm < ApplicationRecord
  validates :guid, :form_id, :form, presence: true

  belongs_to :appeal_submission

  has_kms_key
  has_encrypted :form, key: :kms_key, **lockbox_options
  scope :needs_failure_notification, lambda {
    where(delete_date: nil, failure_notification_sent_at: nil).where('status LIKE ?', '%error%')
  }

  scope :incomplete, -> { where(delete_date: nil) }
end
