# frozen_string_literal: true

require_relative 'gateway'
require_relative 'formatter'

module Forms
  module SubmissionStatuses
    class Report
      def initialize(user_account)
        @gateway = Gateway.new(user_account)
        @formatter = Formatter.new
      end

      def run
        data
        format_data
      end

      def data
        @dataset = @gateway.data
      end

      def format_data
        @formatter.format_data(@dataset)
      end
    end
  end
end
