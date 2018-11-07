# frozen_string_literal: true

module EVSS
  module IntentToFile
    class IntentToFilesResponse < EVSS::Response
      attribute :intent_to_file, Array[EVSS::IntentToFile::IntentToFile]

      def initialize(status, response = nil)
        super(status, response.body) if response
      end
    end
  end
end
