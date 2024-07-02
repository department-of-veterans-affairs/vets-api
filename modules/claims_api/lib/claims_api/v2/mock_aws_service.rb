# frozen_string_literal: true

module ClaimsApi
  module V2
    class MockAwsService
      def store(file_data)
        sleep(sleep_interval)
        ClaimsApi::Logger.log('526 Skipping upload to s3 via claims_load_testing flipper ' \
                              "for filename=#{file_data&.original_filename}")
      end

      private

      def sleep_interval
        randy = Random.new.rand(60..120)
        randy.to_f / 1000
      end
    end
  end
end
