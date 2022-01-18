# frozen_string_literal: true

class OnsiteNotification < ApplicationRecord
  validates :template_id, :va_profile_id, presence: true
  validates :template_id, inclusion: Settings.onsite_notifications.template_ids
end
