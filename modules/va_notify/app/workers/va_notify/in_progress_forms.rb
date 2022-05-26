# frozen_string_literal: true

require 'sidekiq'

module VANotify
  class InProgressForms
    include Sidekiq::Worker

    def perform
      FindInProgressForms.new.to_notify.each do |in_progress_form_id|
        InProgressFormReminder.perform_async(in_progress_form_id)
      end
    end
  end
end
