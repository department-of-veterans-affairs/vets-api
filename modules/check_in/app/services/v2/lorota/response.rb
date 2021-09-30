# frozen_string_literal: true

module V2
  module Lorota
    class Response
      attr_reader :body, :status

      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @body = opts[:response].body || []
        @status = opts[:response].status
      end

      def handle
        value = begin
          Oj.load(body)
        rescue
          body
        end

        case status
        when 200, 400
          { data: value, status: status }
        when 401
          { data: { error: true, message: 'Unauthorized' }, status: status }
        when 404
          { data: { error: true, message: 'We could not find that resource' }, status: status }
        when 403
          { data: { error: true, message: 'Forbidden' }, status: status }
        else
          { data: { error: true, message: 'Something went wrong' }, status: status }
        end
      end
    end
  end
end
