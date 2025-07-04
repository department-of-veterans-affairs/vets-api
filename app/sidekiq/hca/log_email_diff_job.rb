# frozen_string_literal: true

module HCA
  class LogEmailDiffJob
    include Sidekiq::Job
    sidekiq_options retry: false

    def perform(in_progress_form_id, user_uuid, user_account_id)
      return if FormEmailMatchesProfileLog.exists?(
        user_uuid:,
        user_account_id:,
        in_progress_form_id:
      )

      in_progress_form = InProgressForm.find_by(id: in_progress_form_id)
      return if in_progress_form.nil?

      parsed_form = JSON.parse(in_progress_form.form_data)
      form_email = parsed_form['email']

      return if form_email.blank?

      user = User.find(user_uuid)
      va_profile_email = user.va_profile_email

      tag_text = va_profile_email&.downcase == form_email.downcase ? 'same' : 'different'

      record_email_diff(tag_text, user_uuid, user_account_id, in_progress_form_id)
    end

    private

    def record_email_diff(tag_text, user_uuid, user_account_id, in_progress_form_id)
      email_diff_log = FormEmailMatchesProfileLog.create_or_find_by(
        user_uuid:,
        user_account_id:,
        in_progress_form_id:
      )
    
      if email_diff_log.previously_new_record?
        StatsD.increment(
          "api.1010ez.in_progress_form_email.#{tag_text}"
        )
      end
    end
  end
end
