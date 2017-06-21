# frozen_string_literal: true
module EVSS
  module Letters
    Struct.new('RawLetterResponse', :body, :status)
    class MockService
      def mocked_response
        path = Rails.root.join('config', 'evss', 'mock_letters_response.yml')
        @response ||= YAML.load_file(path) if File.exist? path
      end

      def get_letters
        EVSS::Letters::LettersResponse.new(
          body: mocked_response[:body],
          status: mocked_response[:status]
        )
      end
    end
  end
end
