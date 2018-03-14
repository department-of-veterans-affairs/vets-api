# frozen_string_literal: true

module Common
  module Client
    class Response
      include Virtus.model(nullify_blank: true)

      def initialize(status, attributes = nil)
        super(attributes) if attributes
        @status = status
      end

      def ok?
        @status == 200
      end
    end
  end
end
