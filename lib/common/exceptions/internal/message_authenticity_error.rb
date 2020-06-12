# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions::Internal
    # Message Authenticity Error - When a message with a signature cannot be verified
    class MessageAuthenticityError < Common::Exceptions::BaseError
      def initialize(options = {})
        @raw_post = options[:raw_post]
        @signature = options[:signature]
      end

      def errors
        Array(Common::Exceptions::SerializableError.new(i18n_data.merge(source: 'AWS SNS Verification', meta: {
                                                                          raw_post: @raw_post, signature: @signature
                                                                        })))
      end
    end
  end
end
