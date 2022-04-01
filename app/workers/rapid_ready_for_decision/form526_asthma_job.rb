# frozen_string_literal: true

require 'lighthouse/veterans_health/client'

module RapidReadyForDecision
  class Form526AsthmaJob < Form526BaseJob
    STATSD_KEY_PREFIX = 'worker.fast_track.form526_asthma_job'

    sidekiq_options retry: 2

    def assess_data(form526_submission)
      client = lighthouse_client(form526_submission)
      response = client.list_resource('medication_requests')
      med_request_data = RapidReadyForDecision::LighthouseMedicationRequestData.new(response)

      body = <<~BODY
        A single-issue asthma claim for increase was detected and offramped.<br/>
        Submission ID: #{form526_submission.id}<br/>
        Veterans Health API returned #{med_request_data.count} medication requests.<br/>
        <br/>
        Medications by year and status:<br/>
        #{meds_by_year_and_status_as_string(med_request_data)}<br/>
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

    def release_pdf?(_form526_submission)
      false
    end

    private

    def generate_pdf(_form526_submission, _assessed_data)
      raise 'method not implemented yet' # RuntimeError
    end

    def meds_by_year_and_status_as_string(med_request_data)
      medication_request_stats_by_year(med_request_data).map do |year, tallies|
        "- #{year}: #{tallies}"
      end.join("<br/>\n")
    rescue
      'Error formatting medications list!'
    end

    def medication_request_stats_by_year(med_request_data)
      med_request_data.resources.group_by { |mr| Date.parse(mr['authoredOn'])&.year }
                      .transform_values { |mrs| mrs.map { |mr| mr['status'] }.tally }
                      .sort.reverse
    end
  end
end
