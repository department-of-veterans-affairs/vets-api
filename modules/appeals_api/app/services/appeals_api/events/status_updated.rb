module AppealsApi
  module Events
    class StatusUpdated

      def initialize(opts)
        @opts = opts
        return false unless has_required_keys?
      end

      def hlr_status_updated
        AppealsApi::StatusUpdate.create!(
          from: opts[:from],
          to: opts[:to],
          status_update_time: opts[:status_update_time],
          appeal_id: opts[:appeal_id],
          appeal_type: 'AppealsApi::HigherLevelReview',
        )
      end

      def nod_status_updated
        AppealsApi::StatusUpdate.create!(
          from: opts[:from],
          to: opts[:to],
          status_update_time: opts[:status_update_time],
          appeal_id: opts[:appeal_id],
          appeal_type: 'AppealsApi::NoticeOfDisagreement',
        )
      end

      private

      attr_accessor :opts

      def has_required_keys?
        required_keys.all? { |k| opts.key?(k) }
      end

      def required_keys
        %i[from to status_update_time appeal_id]
      end
    end
  end
end
