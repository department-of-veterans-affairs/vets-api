# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class StatusUpdatedJob
    include Sidekiq::Worker

    # Retry for 24 hours
    sidekiq_options retry: 14, unique_for: 1.day

    # @param [Hash] opts
    # @option opts [String] :status_event The callback indicating which appeal type's status was upated. Required.
    # @option opts [Hash] :from The appeal's original status. Required
    # @option opts [String] :to The status to which the appeal should be updated. Required.
    # @option opts [Datetime] :status_update_time The time at which the status update was called. Required.
    # @option opts [String] :statusable_id The associated appeal's guid. Required.

    def perform(opts)
      @opts = opts

      return Rails.logger.error missing_keys_error unless required_keys?

      send(opts['status_event'].to_sym)
    end

    def hlr_status_updated
      AppealsApi::StatusUpdate.create!(
        from: opts['from'],
        to: opts['to'],
        status_update_time: opts['status_update_time'],
        statusable_id: opts['statusable_id'],
        statusable_type: 'AppealsApi::HigherLevelReview'
      )
    end

    def nod_status_updated
      AppealsApi::StatusUpdate.create!(
        from: opts['from'],
        to: opts['to'],
        status_update_time: opts['status_update_time'],
        statusable_id: opts['statusable_id'],
        statusable_type: 'AppealsApi::NoticeOfDisagreement'
      )
    end

    def sc_status_updated
      AppealsApi::StatusUpdate.create!(
        from: opts['from'],
        to: opts['to'],
        status_update_time: opts['status_update_time'],
        statusable_id: opts['statusable_id'],
        statusable_type: 'AppealsApi::SupplementalClaim'
      )
    end

    private

    attr_accessor :opts

    def required_keys?
      required_keys.all? { |k| opts.key?(k) }
    end

    def required_keys
      %w[status_event from to status_update_time statusable_id]
    end

    def missing_keys_error
      "AppealsApi::StatusUpdated: Missing required keys, #{required_keys}"
    end
  end
end
