# frozen_string_literal: true

module HCA
  class LogEmailDiffJob
    include Sidekiq::Worker
    sidekiq_options retry: false

    def perform(in_progress_form_id, user_uuid)
      in_progress_form = InProgressForm.find(in_progress_form_id)
      parsed_form = JSON.parse(in_progress_form.form_data)
      form_email = parsed_form['email']
      email_confirmation = parsed_form['view:email_confirmation']

      return if form_email.blank? || form_email != email_confirmation

      user = User.find(user_uuid)
      va_profile_email = user.va_profile_email

      tag_text = va_profile_email&.downcase == form_email.downcase ? 'same' : 'different'

      StatsD.set(
        'api.1010ez.in_progress_form_email',
        user_uuid,
        sample_rate: 1.0,
        tags: {
          email: tag_text
        }
      )
    end
  end
end
