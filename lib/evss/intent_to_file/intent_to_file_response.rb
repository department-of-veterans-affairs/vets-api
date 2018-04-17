# frozen_string_literal: true

require 'evss/response'
require 'evss/intent_to_file/intent_to_file'

module EVSS
  module IntentToFile
    class IntentToFileResponse < EVSS::Response
      attribute :intent_to_file, EVSS::IntentToFile::IntentToFile

      def initialize(status, response = nil)
        super(status, response.body) if response
      end
    end
  end
end
