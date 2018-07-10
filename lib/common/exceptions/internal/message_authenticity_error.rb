# frozen_string_literal: true

module Common
  module Exceptions
    # Message Authenticity Error - When a message with a signature cannot be verified
    class MessageAuthenticityError < BaseError
      def initialize(options = {})
        @raw_post = options[:raw_post]
        @signature = options[:signature]
      end

      def errors
        Array(SerializableError.new(i18n_data.merge(source: 'AWS SNS Verification', meta: {
                                                      raw_post: @raw_post, signature: @signature
                                                    })))
      end
    end
  end
end
