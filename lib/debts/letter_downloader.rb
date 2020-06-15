module Debts
  class LetterDownloader
    def initialize(file_number)
      @file_number = file_number
      @client = VBMS::Client.from_env_vars(env_name: Settings.vbms.env)
    end

    def list_letters
      res = @client.send_request(
        VBMS::Requests::FindDocumentVersionReference.new(@file_number)
      )
      binding.pry; fail
    end
  end
end
