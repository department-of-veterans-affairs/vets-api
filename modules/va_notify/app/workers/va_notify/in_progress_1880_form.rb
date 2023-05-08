# frozen_string_literal: true

require 'sidekiq'

module VANotify
  class InProgress1880Form
    include Sidekiq::Worker

    FORM_NAME = '26-1880'

    def perform
      return unless Flipper.enabled?(:in_progress_1880_form_cron)

      date_range = [
        24.hours.ago..23.hours.ago
      ]

      InProgressForm.where(form_id: FORM_NAME).where(updated_at: date_range).order(:created_at).pluck(:id).each do |id|
        InProgress1880FormReminder.perform_async(id)
      end
    end
  end
end
