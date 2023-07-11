# frozen_string_literal: true

class OnsiteNotification < ApplicationRecord
  validates :template_id, :va_profile_id, presence: true
  validates :template_id, inclusion: Settings.onsite_notifications.template_ids

  def self.for_user(user, include_dismissed: false)
    notifications = where(va_profile_id: user.vet360_id).order(created_at: :desc)
    return notifications if include_dismissed

    notifications.where(dismissed: false)
  end
end
