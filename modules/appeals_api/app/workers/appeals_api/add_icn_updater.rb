# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/monitored_worker'

module AppealsApi
  class AddIcnUpdater
    include Sidekiq::Worker
    include Sidekiq::MonitoredWorker

    def perform(appeal_id, appeal_class_str)
      return unless Flipper.enabled?(:decision_review_icn_updater_enabled)

      appeal_class = Object.const_get(appeal_class_str)
      appeal = appeal_class.find_by(id: appeal_id)

      return if appeal.blank?

      if appeal.form_data.nil? && appeal.auth_headers.nil?
        Rails.logger.error "#{appeal_class_str} missing PII, can't retrieve ICN. Appeal ID:#{appeal_id}."
      else
        appeal.update!(veteran_icn: target_veteran(appeal).mpi_icn)
      end
    end

    def retry_limits_for_notification
      # Notify at 1 day, 3 days, 7 days, 14 days
      [14, 17, 20, 23]
    end

    def notify(retry_params)
      AppealsApi::Slack::Messager.new(retry_params, notification_type: :error_retry).notify!
    end

    private

    def target_veteran(appeal)
      veteran ||= Appellant.new(
        type: :veteran,
        auth_headers: appeal.auth_headers,
        form_data: appeal.form_data&.dig('data', 'attributes', 'veteran')
      )

      mpi_veteran ||= AppealsApi::Veteran.new(
        ssn: veteran.ssn,
        first_name: veteran.first_name,
        last_name: veteran.last_name,
        birth_date: veteran.birth_date.iso8601
      )

      mpi_veteran
    end
  end
end
