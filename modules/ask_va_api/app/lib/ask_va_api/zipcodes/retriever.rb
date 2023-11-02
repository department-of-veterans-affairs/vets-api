# frozen_string_literal: true

module AskVAApi
  module Zipcodes
    ENDPOINT = 'get_zipcodes_mock_data.json'

    class Retriever
      attr_reader :service, :zip

      def initialize(zip:, service: nil)
        @zip = zip
        @service = service
      end

      def call
        zips_array = fetch_data(criteria: { zip: })

        zips_array.map do |sub|
          Entity.new(sub)
        end
      rescue => e
        ErrorHandler.handle_service_error(e)
      end

      private

      def fetch_data(criteria:)
        file_path = "modules/ask_va_api/config/locales/#{ENDPOINT}"

        data = JSON.parse(File.read(file_path), symbolize_names: true)[:data]

        data.select { |e| e[:zip].start_with?(criteria[:zip]) }
      end
    end
  end
end
