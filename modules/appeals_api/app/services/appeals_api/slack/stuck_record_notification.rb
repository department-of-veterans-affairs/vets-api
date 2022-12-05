# frozen_string_literal: true

module AppealsApi
  module Slack
    class StuckRecordNotification
      def initialize(records)
        @records = records.sort_by { |r| r[:created_at] }
      end

      def message_text
        <<~MESSAGE
          :warning: The following appeal records are stuck:

          #{records.map { |r| format_list_item(**r) }.join("\n")}
        MESSAGE
      end

      private

      attr_accessor :records

      def format_list_item(record_type:, id:, status:, created_at:)
        %(* #{record_type} `#{id}` (#{status}, created #{created_at.iso8601}))
      end
    end
  end
end
