# frozen_string_literal: true

require 'common/client/concerns/service_status'
require 'evss/response'

module EVSS
  module IntentToFile
    class IntentToFileResponse < EVSS::Response
      attribute :intent_to_file, Array[EVSS::IntentToFile::IntentToFile]

      def initialize(status, response = nil)
        super(status, response.body) if response
      end
    end
  end
end
