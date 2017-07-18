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
        response = YAML.load_file(path) if File.exist? path
        user = response[ssn]
        if user.nil?
          Rails.logger.warn("No user found with ssn: #{ssn} in config/mock_letters_response.yml, trying default...")
          user = response['default']
        end
        user
      rescue NoMethodError => e
        Rails.logger.error("No user with ssn: #{ssn} and no default in config/mock_letters_response.yml")
        raise e
      end

      def get_letters
        letters = mocked_response[:get_letters]
        raw_response = Struct::RawLetterResponse.new(letters[:body], letters[:status])
        EVSS::Letters::LettersResponse.new(raw_response.status, raw_response)
      rescue NoMethodError => e
        Rails.logger.error(
          "User with ssn: #{ssn} does not have key :get_letters in config/mock_letters_response.yml"
        )
        raise e
      end

      def get_letter_beneficiary
        beneficiary = mocked_response[:get_letter_beneficiary]
        raw_response = Struct::RawLetterResponse.new(beneficiary[:body], beneficiary[:status])
        EVSS::Letters::BeneficiaryResponse.new(raw_response.status, raw_response)
      rescue NoMethodError => e
        Rails.logger.error(
          "User with ssn: #{ssn} does not have key :get_letter_beneficiary in config/mock_letters_response.yml"
        )
        raise e
      end

      def download_by_type(type, _options = nil)
        path = Rails.root.join(mocked_response[:download_letter_by_type][type])
        File.open(path, 'rb', &:read)
      rescue NoMethodError => e
        Rails.logger.error(
          "User with ssn: #{ssn} does not have key :download_letter_by_type in config/mock_letters_response.yml"
        )
        raise e
      end

      private

      def ssn
        @headers['va_eauth_pnid']
      end
    end
  end
end
