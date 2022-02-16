# frozen_string_literal: true

class OnsiteNotification < ApplicationRecord
  validates :template_id, :va_profile_id, presence: true
  validates :template_id, inclusion: Settings.onsite_notifications.template_ids

  def self.for_user(user)
    where(va_profile_id: user.vet360_id, dismissed: false)
  end
end
