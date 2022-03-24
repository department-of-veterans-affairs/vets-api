# frozen_string_literal: true

require 'sidekiq'

module VANotify
  class InProgressForms
    include Sidekiq::Worker

    def perform
      FindInProgressForms.new.to_notify.each do |_user_uuid, in_progress_forms|
        in_progress_form_ids = in_progress_forms.map(&:id)
        InProgressFormNotifier.perform_async(in_progress_form_ids)
      end
    end
  end
end
