# frozen_string_literal: true

module AppealsApi
  module Events
    class StatusUpdated
      def initialize(opts)
        @opts = opts
        raise InvalidKeys unless required_keys?
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
        %w[from to status_update_time statusable_id]
      end
    end

    class InvalidKeys < StandardError; end
  end
end
