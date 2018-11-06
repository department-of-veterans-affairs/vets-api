# frozen_string_literal: true

module EVSS
  module Dependents
    class Service < EVSS::Service
      include Common::Client::Monitoring
      configuration EVSS::Dependents::Configuration

      def retrieve
        with_monitoring do
          raw_response = perform(:get, 'load/retrieve')
          EVSS::Dependents::RetrieveInfoResponse.new(raw_response.status, raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end

      def submit
        info = EVSS::Dependents::RetrievedInfo.for_user(@user)
        info.body
        # construct submission
        # then delete:
        info.delete
      end
    end
  end
end
