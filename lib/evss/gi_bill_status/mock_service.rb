# frozen_string_literal: true
module EVSS
  module GiBillStatus
    Struct.new('RawGiBillResponse', :body, :status)
    class MockService
      def mocked_response
        path = Rails.root.join('config', 'evss', 'mock_gi_bill_status_response.yml')
        @response ||= YAML.load_file(path) if File.exist? path
      end

      def get_gi_bill_status
        raw_response = Struct::RawGiBillResponse.new(mocked_response[:body], mocked_response[:status])
        EVSS::GiBillStatus::GiBillStatusResponse.new(mocked_response[:status], raw_response)
      end
    end
  end
end
