# frozen_string_literal: true
module EVSS
  module Letters
    Struct.new('RawLetterResponse', :body, :status)
    class MockService
      def mocked_response
        path = Rails.root.join('config', 'evss', 'mock_letters_response.yml')
        @response ||= YAML.load_file(path) if File.exist? path
      end

      def letters_by_user(_user)
        raw_response = Struct::RawLetterResponse.new(mocked_response[:body], mocked_response[:status])
        EVSS::Letters::LettersResponse.new(raw_response)
      end
    end
  end
end
