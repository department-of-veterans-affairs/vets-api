# frozen_string_literal: true

# This is a one-time rake task and it is not meant to be run after July 2024
# If you see this file in the code base after July 2024, it means that Eric Tillberg forgot to remove it
namespace :simple_forms_api do
  task va_notify_intent_to_file: :environment do
    date_range = (Date.new(2024, 5, 30)..Date.new(2024, 6, 4))
    submissions = FormSubmission.where(created_at: date_range, form_type: '21-0966').where.not(user_account: nil)
    submissions.each do |submission|
      next unless submission

      SimpleFormsApi::VANotifyIntentToFileJob.perform_later(submission)
    end
  end
end
