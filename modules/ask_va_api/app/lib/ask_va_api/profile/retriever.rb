# frozen_string_literal: true

module AskVAApi
  module Profile
    ENDPOINT = 'profile'
    DEFAULT_ICN = '1013694290V263188'

    class InvalidInquiryError < StandardError; end

    class Retriever
      attr_reader :icn, :user_mock_data

      def initialize(icn: DEFAULT_ICN, user_mock_data: nil)
        @icn = icn
        @user_mock_data = user_mock_data
      end

      def call
        validate_input
        data = fetch_data.merge(icn:)
        Entity.new(data)
      rescue => e
        ErrorHandler.handle_service_error(e)
      end

      private

      def default_service
        Crm::Service.new(icn: '1008709396V637156')
      end

      def fetch_data
        user_mock_data ? load_mock_data : fetch_service_data
      end

      def fetch_service_data
        response = default_service.call(endpoint: ENDPOINT)
        handle_response_data(response)
      end

      def load_mock_data
        data = if icn == '1008709396V637156'
                 File.read('modules/ask_va_api/config/locales/get_profile_mock_data.json')
               else
                 generate_mock_error
               end
        JSON.parse(data, symbolize_names: true).tap do |parsed_data|
          handle_response_data(parsed_data)
        end[:Data]
      end

      def generate_mock_error
        {
          'Data' => nil,
          'message' => 'No Contact found',
          'ExceptionOccurred' => true,
          'ExceptionMessage' => 'No Contact found',
          'MessageId' => '4c577bcf-4762-4cfc-a239-69be9dc9174f'
        }.to_json
      end

      def handle_response_data(data)
        if data[:Data].nil?
          raise InvalidInquiryError, data[:message]
        else
          data[:Data]
        end
      end

      def validate_input
        raise ArgumentError, 'Invalid ICN' if icn.blank?
      end
    end
  end
end
