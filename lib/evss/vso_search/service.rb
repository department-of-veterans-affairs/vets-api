# frozen_string_literal: true

module EVSS
  module VsoSearch
    class Service < EVSS::Service
      configuration EVSS::VsoSearch::Configuration

      def get_current_info(addtional_headers = {})
        with_monitoring_and_error_handling do
          perform(:post, 'getCurrentInfo', nil, request_headers(addtional_headers)).body
        end
      end

      private

      def request_headers(additional_headers)
        {
          'ssn' => @user.ssn,
          'Authorization' => "Token token=#{Settings.appeals.app_token}"
        }.merge(additional_headers)
      end
    end
  end
end
