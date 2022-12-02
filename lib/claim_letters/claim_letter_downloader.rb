# frozen_string_literal: true

require 'claim_letters/claim_letter_test_data'

module ClaimStatusTool
  class ClaimLetterDownloader
    def initialize(user)
      @user = user
      @client = VBMS::Client.from_env_vars(env_name: Settings.vbms.env) unless Rails.env.development? || Rails.env.test?
    end

    def get_letters
      @letters ||= begin
        res = nil

        if !Rails.env.development? && !Rails.env.test?
          req = VBMS::Requests::FindDocumentVersionReference.new(file_number)
          res = @client.send_request(req)
        else
          res = ClaimLetterTestData::TEST_DATA
        end

        format_letter_data(res)
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

    private

    # 184: Notification Letter (e.g. VA 20-8993, VA 21-0290, PCGL)
    # 339: Rating Decision Letter
    def doc_type_allowlist
      %w[184].freeze
    end

    def file_number
      # In staging, some users don't have a participant_id
      return @user.ssn if @user.participant_id.blank?

      bgs_file_number = BGS::People::Request.new.find_person_by_participant_id(user: @user).file_number
      (bgs_file_number.presence || @user.ssn)
    end

    def filter_letters(document)
      return nil unless doc_type_allowlist.include?(document[:doc_type])

      document.marshal_dump
    end

    def format_letter_data(docs)
      letters = docs.map { |d| filter_letters(d) }.compact
      letters.sort_by { |d| d[:received_at] }.reverse
    end

    def verify_letter_in_folder(document_id)
      letters = get_letters

      raise Common::Exceptions::Unauthorized unless letters.any? do |document|
        document[:document_id] == document_id
      end
    end
  end
end
