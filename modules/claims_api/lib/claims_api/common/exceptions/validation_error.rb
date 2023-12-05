# frozen_string_literal: true

module ClaimsApi
  module Error
    class ValidationError < StandardError
      def initialize
        @errors = []

        super
      end

      def add_error(detail: nil, source: nil, title: 'Unprocessable', status: '422')
        error_object = build_error_object(detail, source, title, status.to_s)
        @errors.push(error_object)
      end

      def build_error_object(detail, source, title, status)
        {
          title:,
          status:,
          source:,
          detail:
        }
      end

      def errors
        instance_variable_get(:@errors)
      end
    end
  end
end
