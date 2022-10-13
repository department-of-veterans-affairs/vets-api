# frozen_string_literal: true

require 'claim_letters/claim_letter_test_data'

module ClaimStatusTool
  class ClaimLetterDownloader
    def initialize(ssn)
      @ssn = ssn
      @client = VBMS::Client.from_env_vars(env_name: Settings.vbms.env) unless Rails.env.development? || Rails.env.test?
    end

    def list_letters
      if !Rails.env.development? && !Rails.env.test?
        req = VBMS::Requests::FindDocumentSeriesReference.new(@ssn)
        res = @client.send_request(req)
        docs = format_letter_data(res)
      else
        docs = format_letter_data(ClaimLetterTestData::TEST_DATA)
      end
      docs
    end

    def verify_letter_in_folder(document_id)
      letters = list_letters
      raise Common::Exceptions::Unauthorized unless letters.any? do |document|
        document[:document_id] == document_id
      end
    end

    def get_letter(document_id)
      verify_letter_in_folder(document_id)

      if !Rails.env.development? && !Rails.env.test?
        f = @client.send_request(VBMS::Requests::GetDocumentContent.new(document_id))
        yield f.read, 'application/pdf', 'attachment', 'ClaimLetter.pdf'
      else
        File.open(ClaimLetterTestData::TEST_FILE_PATH, 'r') do |f|
          yield f.read, 'application/pdf', 'attachment', 'ClaimLetter.pdf'
        end
      end
    end

    def format_letter_data(docs)
      letters = docs.select { |d| d[:doc_type] == '184' }
      letters.sort_by do |d|
        DateTime.strptime(d[:upload_date], '%a, %d %b %Y')
      end.reverse
    end
  end
end
