# frozen_string_literal: true

require 'sidekiq'

module DecisionReviews
  class DeleteSecondaryAppealFormsJob
    include Sidekiq::Job

    # No need to retry since the schedule will run this periodically
    sidekiq_options retry: false

    STATSD_KEY_PREFIX = 'worker.decision_review.delete_secondary_appeal_forms'

    def perform
      return unless enabled?

      deleted_secondary_forms = SecondaryAppealForm.where(delete_date: ..DateTime.now).destroy_all

      StatsD.increment("#{STATSD_KEY_PREFIX}.count", deleted_secondary_forms.size)

      Rails.logger.info('DecisionReviews::DeleteSecondaryAppealFormsJob completed successfully',
                        secondary_forms_deleted: deleted_secondary_forms.size)

      nil
    rescue => e
      StatsD.increment("#{STATSD_KEY_PREFIX}.error")
      Rails.logger.error('DecisionReviews::DeleteSecondaryAppealFormsJob perform exception', e.message)
    end

    private

    def enabled?
      Flipper.enabled? :decision_review_delete_secondary_appeal_forms_enabled
    end
  end
end
