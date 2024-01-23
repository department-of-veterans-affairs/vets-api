# frozen_string_literal: true

module ClaimsApi
  module V2
    class MockAwsService
      def sleep_interval
        Settings.claims_api.mock_aws_service.sleep_interval
      end

      def store(file_data)
        sleep(sleep_interval)
        ClaimsApi::Logger.log("526 Skipping upload to s3 via claims_load_testing flipper " \
                              "for filename=#{file_data.original_filename}")
      end
    end
  end
end
