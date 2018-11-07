# frozen_string_literal: true

module EVSS
  module IntentToFile
    class IntentToFileResponse < EVSS::Response
      attribute :intent_to_file, EVSS::IntentToFile::IntentToFile

      def initialize(status, response = nil)
        super(status, response.body) if response
      end

      def cache?
        ok? && !intent_to_file.expires_within_one_day?
      end
    end
  end
end
