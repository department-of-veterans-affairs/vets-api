# frozen_string_literal: true

require 'sidekiq'
require 'decision_review_v1/service'

module DecisionReview
  class SecondaryAppealForm4142StatusUpdaterJob
    include Sidekiq::Job

    RETENTION_PERIOD = 59.days

    SUCCESSFUL_STATUS = %w[vbms].freeze

    ERROR_STATUS = 'error'

    ATTRIBUTES_TO_STORE = %w[status detail createDate updateDate].freeze

    STATSD_KEY_PREFIX = 'worker.decision_review.secondary_appeal_form4142_status_updater'

    # No need to retry since the schedule will run this every hour
    sidekiq_options retry: false, unique_for: 30.minutes

    def perform
      StatsD.increment("#{STATSD_KEY_PREFIX}.processing_records", forms.size)

      forms.each do |form|
        status, attributes = get_status_and_attributes(form.guid)
        handle_form_status_metrics_and_logging(form, status)
        update_form_status(form, status, attributes)
      rescue => e
        StatsD.increment("#{STATSD_KEY_PREFIX}.error")
        Rails.logger.error('DecisionReview::SecondaryAppealForm4142StatusUpdaterJob error',
                           { guid: form.guid, message: e.message })
      end
    end

    private

    def decision_review_service
      @service ||= DecisionReviewV1::Service.new
    end

    def forms
      @forms ||= SecondaryAppealForm.where(form_id: '21-4142', delete_date: nil)
    end

    def get_status_and_attributes(guid)
      response = decision_review_service.get_supplemental_claim_upload(uuid: guid).body
      attributes = response.dig('data', 'attributes').slice(*ATTRIBUTES_TO_STORE)
      status = attributes['status']

      [status, attributes]
    end

    def update_form_status(form, status, attributes)
      if SUCCESSFUL_STATUS.include?(status)
        StatsD.increment("#{STATSD_KEY_PREFIX}.delete_date_update")
        delete_date = (Time.current + RETENTION_PERIOD)
      else
        delete_date = nil
      end
      form.update!(status: attributes.to_json, status_updated_at: Time.current, delete_date:)
    end

    def handle_form_status_metrics_and_logging(form, status)
      # Skip logging and statsd metrics when there is no status change
      return if JSON.parse(form.status || '{}')['status'] == status

      if status == ERROR_STATUS
        Rails.logger.info('DecisionReview::SecondaryAppealForm4142StatusUpdaterJob status error', guid: form.guid)
        tags = ['service:supplemental-claims-4142', 'function: PDF submission to Lighthouse']
        StatsD.increment('silent_failure', tags:)
      end

      StatsD.increment("#{STATSD_KEY_PREFIX}.status", tags: ["status:#{status}"])
    end
  end
end
