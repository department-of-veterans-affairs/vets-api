# frozen_string_literal: true

module ClaimsApi
  module V2
    class MockBDUploaderService
      def store(file_data)
        ClaimsApi::Logger.log('526 Skipping upload to s3 via claims_api.pdf_generator_526.mock: true ' \
                              "for filename=#{file_data&.original_filename}")
      end
    end
  end
end
