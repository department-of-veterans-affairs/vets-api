# frozen_string_literal: true

module AppealsApi
  module Slack
    class StuckRecordNotification < AppealsApi::Slack::DefaultNotification
      # Params should be a list of items with keys ready for #format_list_item
      def initialize(params)
        super
        @params.sort_by! { |p| p[:created_at] }
      end

      def message_text
        <<~MESSAGE
          ENVIRONMENT: #{environment}

          :warning: The following appeal records are stuck:

          #{params.map { |p| format_list_item(**p) }.join("\n")}
        MESSAGE
      end

      private

      def format_list_item(record_type:, id:, status:, created_at:)
        %(* #{record_type} `#{id}` (#{status}, created #{created_at.iso8601}))
      end
    end
  end
end
