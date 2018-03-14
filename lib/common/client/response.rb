# frozen_string_literal: true

module Common
  module Client
    class Response
      include ActiveModel::Serialization
      include Virtus.model(nullify_blank: true)

      attribute :status, Integer

      def initialize(status, attributes = nil)
        super(attributes) if attributes
        self.status = status
      end

      def ok?
        status == 200
      end
    end
  end
end
