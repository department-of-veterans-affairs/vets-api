# frozen_string_literal: true

require 'va_notify/in_progress_form_helper'

module VANotify
  class InProgressFormReminder
    include Sidekiq::Job
    include SentryLogging
    sidekiq_options retry: 14

    class MissingICN < StandardError; end

    def perform(form_id)
      @in_progress_form = InProgressForm.find(form_id)
      return unless enabled?

      @veteran = VANotify::Veteran.new(in_progress_form)
      return if veteran.first_name.blank?
      return if veteran.icn.blank?
      return if in_progress_form.user_account_id.blank?

      if only_one_supported_in_progress_form?
        template_id = VANotify::InProgressFormHelper::TEMPLATE_ID.fetch(in_progress_form.form_id)
        UserAccountJob.perform_async(in_progress_form.user_account_id,
                                     template_id,
                                     personalisation_details_single)
      elsif oldest_in_progress_form?
        template_id = VANotify::InProgressFormHelper::TEMPLATE_ID.fetch('generic')
        UserAccountJob.perform_async(in_progress_form.user_account_id,
                                     template_id,
                                     personalisation_details_multiple)
      end
    rescue VANotify::Veteran::MPINameError, VANotify::Veteran::MPIError
      nil
    end

    private

    attr_accessor :in_progress_form, :veteran

    def enabled?
      case @in_progress_form.form_id
      when '686C-674'
        true
      when '1010ez'
        Flipper.enabled?(:in_progress_form_reminder_1010ez)
      when '21-526EZ'
        Flipper.enabled?(:in_progress_form_reminder_526ez)
      else
        false
      end
    end

    def only_one_supported_in_progress_form?
      InProgressForm.where(user_uuid: in_progress_form.user_uuid,
                           form_id: FindInProgressForms::RELEVANT_FORMS).count == 1
    end

    def oldest_in_progress_form?
      other_updated_at = InProgressForm.where(user_uuid: in_progress_form.user_uuid,
                                              form_id: FindInProgressForms::RELEVANT_FORMS).pluck(:updated_at)
      other_updated_at.all? { |date| in_progress_form.updated_at <= date }
    end

    def personalisation_details_single
      {
        'first_name' => veteran.first_name.upcase,
        'date' => in_progress_form.expires_at.strftime('%B %d, %Y'),
        'form_age' => VANotify::InProgressFormHelper.form_age(in_progress_form)
      }
    end

    def personalisation_details_multiple
      in_progress_forms = InProgressForm.where(form_id: FindInProgressForms::RELEVANT_FORMS,
                                               user_uuid: in_progress_form.user_uuid).order(:expires_at)
      personalisation = {}
      personalisation['formatted_form_data'] = in_progress_forms.map do |form|
        friendly_form_name = VANotify::InProgressFormHelper::FRIENDLY_FORM_SUMMARY.fetch(form.form_id)
        friendly_form_id = VANotify::InProgressFormHelper::FRIENDLY_FORM_ID.fetch(form.form_id)
        <<~FORM_DATA

          ^ FORM #{friendly_form_id}
          ^
          ^__#{friendly_form_name}__
          ^
          ^_Application expires on:_ #{form.expires_at.strftime('%B %d, %Y')}

        FORM_DATA
      end.join("\n^---\n")
      personalisation['first_name'] = veteran.first_name.upcase
      personalisation
    end
  end
end
