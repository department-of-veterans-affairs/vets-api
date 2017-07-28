# frozen_string_literal: true
module EVSS
  module Letters
    Struct.new('RawLetterResponse', :body, :status)

    class MockService
      def mocked_response(user)
        path = Rails.root.join('config', 'evss', 'mock_letters_response.yml')
        response = YAML.load_file(path) if File.exist? path
        user_response = response[user.ssn]
        if user_response.nil?
          Rails.logger.warn("No user found with ssn: #{user.ssn} in config/mock_letters_response.yml, trying default...")
          user_response = response['default']
        end
        user_response
      rescue NoMethodError => e
        Rails.logger.error("No user with ssn: #{user.ssn} and no default in config/mock_letters_response.yml")
        raise e
      end

      def get_letters(user)
        letters = mocked_response(user)[:get_letters]
        raw_response = Struct::RawLetterResponse.new(letters[:body], letters[:status])
        EVSS::Letters::LettersResponse.new(raw_response.status, raw_response)
      rescue NoMethodError => e
        Rails.logger.error(
          "User with ssn: #{user.ssn} does not have key :get_letters in config/mock_letters_response.yml"
        )
        raise e
      end

      def get_letter_beneficiary(user)
        beneficiary = mocked_response(user)[:get_letter_beneficiary]
        raw_response = Struct::RawLetterResponse.new(beneficiary[:body], beneficiary[:status])
        EVSS::Letters::BeneficiaryResponse.new(raw_response.status, raw_response)
      rescue NoMethodError => e
        Rails.logger.error(
          "User with ssn: #{user.ssn} does not have key :get_letter_beneficiary in config/mock_letters_response.yml"
        )
        raise e
      end

      def download_by_type(user, type, _options = nil)
        path = Rails.root.join(mocked_response(user)[:download_letter_by_type][type])
        File.open(path, 'rb', &:read)
      rescue NoMethodError => e
        Rails.logger.error(
          "User with ssn: #{user.ssn} does not have key :download_letter_by_type in config/mock_letters_response.yml"
        )
        raise e
      end
    end
  end
end
