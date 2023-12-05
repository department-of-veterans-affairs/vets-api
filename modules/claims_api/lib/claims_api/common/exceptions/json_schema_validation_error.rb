# frozen_string_literal: true

module ClaimsApi
  module Error
    class JsonSchemaValidationError < StandardError
      def initialize(error)
        @title = error[:errors][0][:title] || 'Unprocessable Entity'
        @source = error[:errors][0][:source]
        @status = error[:errors][0][:status]
        @detail = error[:errors][0][:detail]

        super
      end

      def errors
        [
          {
            title: @title,
            detail: @detail,
            status: @status.to_s, # LH standards want this be a string
            source: "data/attributes#{@source}"
          }
        ]
      end

      def status
        'not implmented'
      end

      def status_code
        @status || '422'
      end
    end
  end
end
