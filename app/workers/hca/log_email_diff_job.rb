# frozen_string_literal: true

module HCA
  class LogEmailDiffJob
    include Sidekiq::Worker
    sidekiq_options retry: false

    def perform(in_progress_form_id, user_uuid)
      redis_key = "HCA::LogEmailDiffJob:#{user_uuid}"
      return if $redis.get(redis_key).present?

      in_progress_form = InProgressForm.find(in_progress_form_id)
      parsed_form = JSON.parse(in_progress_form.form_data)
      form_email = parsed_form['email']
      email_confirmation = parsed_form['view:email_confirmation']

      return if form_email.blank? || form_email != email_confirmation

      user = User.find(user_uuid)
      va_profile_email = user.va_profile_email

      tag_text = va_profile_email&.downcase == form_email.downcase ? 'same' : 'different'

      StatsD.increment(
        "api.1010ez.in_progress_form_email.#{tag_text}"
      )
      $redis.set(redis_key, 't')
    end
  end
end
