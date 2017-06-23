# frozen_string_literal: true
module EVSS
  module Letters
    Struct.new('RawLetterResponse', :body, :status)

    class MockService
      def initialize(headers)
        @headers = headers
      end

      def mocked_response
        path = Rails.root.join('config', 'evss', 'mock_letters_response.yml')
        @response ||= YAML.load_file(path) if File.exist? path
      end

      def get_letters
        letters = mocked_response[:get_letters][ssn]
        raw_response = Struct::RawLetterResponse.new(letters[:body], letters[:status])
        EVSS::Letters::LettersResponse.new(raw_response.status, raw_response)
      end

      def get_letter_beneficiary
        beneficiary = mocked_response[:get_letter_beneficiary][ssn]
        raw_response = Struct::RawLetterResponse.new(beneficiary[:body], beneficiary[:status])
        EVSS::Letters::BeneficiaryResponse.new(raw_response.status, raw_response)
      end

      def download_letter_by_type(type)
        path = Rails.root.join(mocked_response[:download_letter_by_type][ssn][type])
        File.open(path, 'rb') { |io| io.read }
      end

      private

      def ssn
        @headers['va_eauth_pnid']
      end
    end
  end
end
