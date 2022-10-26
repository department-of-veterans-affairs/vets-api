# frozen_string_literal: true

require 'claim_letters/claim_letter_test_data'

module ClaimStatusTool
  class ClaimLetterDownloader
    def initialize(user)
      @user = user
      @client = VBMS::Client.from_env_vars(env_name: Settings.vbms.env) unless Rails.env.development? || Rails.env.test?
    end

    def list_letters
      if !Rails.env.development? && !Rails.env.test?
        req = VBMS::Requests::FindDocumentVersionReference.new(file_number)
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
        req = VBMS::Requests::GetDocumentContent.new(document_id)
        res = @client.send_request(req)

        yield res.content, 'application/pdf', 'attachment', 'ClaimLetter.pdf'
      else
        File.open(ClaimLetterTestData::TEST_FILE_PATH, 'r') do |f|
          yield f.read, 'application/pdf', 'attachment', 'ClaimLetter.pdf'
        end
      end
    end

    def format_letter_data(docs)
      letters = Marshal.load(Marshal.dump(docs))
      letters = letters.select { |d| d[:doc_type] == '184' }
      letters = letters.sort_by(&:upload_date).reverse
      letters = letters.map do |d|
        d[:upload_date] = DateTime.parse(d[:upload_date].to_s).strftime('%a, %d %b %Y')
        d[:received_at] = DateTime.parse(d[:received_at].to_s).strftime('%a, %d %b %Y')
        d
      end
      letters.map(&:marshal_dump)
    end

    private

    def file_number
      return @user.ssn if @user.participant_id.blank?  # <- Some staging accounts don't have a participant id.

      bgs_file_number = BGS::People::Request.new.find_person_by_participant_id(user: @user).file_number
      bgs_file_number.empty? ? @user.ssn : bgs_file_number
    end
  end
end
