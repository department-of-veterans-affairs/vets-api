# frozen_string_literal: true

require 'claim_letters/claim_letter_test_data'

module ClaimStatusTool
  class ClaimLetterDownloader
    FILENAME = 'ClaimLetter'
    # 184: Notification Letter (e.g. VA 20-8993, VA 21-0290, PCGL)
    # 339: Rating Decision Letter
    DOC_TYPE_ALLOWLIST = %w[184].freeze

    def initialize(user)
      @user = user
      @client = VBMS::Client.from_env_vars(env_name: Settings.vbms.env) unless Rails.env.development? || Rails.env.test?
    end

    def get_letters
      res = nil

      if !Rails.env.development? && !Rails.env.test?
        req = VBMS::Requests::FindDocumentVersionReference.new(file_number)
        res = @client.send_request(req)
      else
        res = ClaimLetterTestData::TEST_DATA
      end

      format_letter_data(res)
    rescue VBMS::FilenumberDoesNotExist
      []
    end

    def get_letter(document_id)
      letter_details = get_letter_details(document_id)
      raise Common::Exceptions::RecordNotFound, document_id if letter_details.nil?

      filename = filename_with_date(letter_details[:received_at])

      if !Rails.env.development? && !Rails.env.test?
        req = VBMS::Requests::GetDocumentContent.new(document_id)
        res = @client.send_request(req)

        yield res.content, 'application/pdf', 'attachment', filename
      else
        File.open(ClaimLetterTestData::TEST_FILE_PATH, 'r') do |f|
          yield f.read, 'application/pdf', 'attachment', filename
        end
      end
    end

    private

    def file_number
      # In staging, some users don't have a participant_id
      return @user.ssn if @user.participant_id.blank?

      bgs_file_number = BGS::People::Request.new.find_person_by_participant_id(user: @user).file_number
      (bgs_file_number.presence || @user.ssn)
    end

    def filter_letters(document)
      return nil unless DOC_TYPE_ALLOWLIST.include?(document[:doc_type])

      document.marshal_dump
    end

    def format_letter_data(docs)
      letters = docs.map { |d| filter_letters(d) }.compact
      # TODO: (rare) Handle nil received_at
      letters.sort_by { |d| d[:received_at] }.reverse
    end

    def get_letter_details(document_id)
      letters = get_letters
      letters.find { |d| d[:document_id] == document_id }
    end

    def filename_with_date(filedate)
      "#{FILENAME}-#{filedate.year}-#{filedate.month}-#{filedate.day}.pdf"
    end
  end
end
