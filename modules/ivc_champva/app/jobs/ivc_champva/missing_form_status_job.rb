# frozen_string_literal: true

require 'sidekiq'

# This job grabs all IVC Forms that are missing a status update from the third-party Pega
# Returns a sends stats to DataDog with the form ids
module IvcChampva
  class MissingFormStatusJob
    include Sidekiq::Job

    def perform
      return unless Settings.ivc_forms.sidekiq.missing_form_status_job.enabled

      forms = IvcChampvaForm.where(pega_status: nil)

      return unless forms.any?

      # Send the count of forms to DataDog
      StatsD.gauge('ivc_champva.forms_missing_status.count', forms.count)

      # Send each form UUID to DataDog
      forms.each do |form|
        StatsD.increment('ivc_champva.form_missing_status', tags: ["id:#{form.id}"])
        # TODO: Pending a policy decision, we'll want to check if any forms have
        # been missing a status for > X days. If so, here's where we'll also want
        # to send the user an email asking them to resubmit their form.
      end
    rescue => e
      Rails.logger.error "IVC Forms MissingFormStatusJob Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end
