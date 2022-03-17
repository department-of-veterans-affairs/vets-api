# frozen_string_literal: true

require 'lighthouse/veterans_health/client'

module RapidReadyForDecision
  class Form526AsthmaJob < Form526BaseJob
    STATSD_KEY_PREFIX = 'worker.fast_track.form526_asthma_job'

    sidekiq_options retry: 2

    def assess_data(form526_submission)
      client = lighthouse_client(form526_submission)
      medication_requests = client.list_resource('medication_requests').presence || []

      body = <<~BODY
        A single-issue asthma claim for increase was detected and offramped.<br/>
        Veterans Health API returned #{medication_requests.count} medication requests.
      BODY
      ActionMailer::Base.mail(
        from: ApplicationMailer.default[:from],
        to: Settings.rrd.event_tracking.recipients,
        subject: 'RRD claim - Offramped',
        body: body
      ).deliver_now

      # returning nil will short-circuit the PDF generation step
      nil
    end

    private

    def generate_pdf(_form526_submission, _assessed_data)
      raise 'method not implemented yet' # RuntimeError
    end
  end
end
