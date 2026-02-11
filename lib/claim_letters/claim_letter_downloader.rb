# frozen_string_literal: true

require 'claim_letters/claim_letter_test_data'
require 'claim_letters/responses/claim_letters_response'
require 'claim_letters/utils/letter_transformer'
require 'claim_letters/utils/doctype_service'
require 'claim_letters/utils/user_helper'

module ClaimStatusTool
  class ClaimLetterDownloader
    include ClaimLetters::Utils::LetterTransformer
    include ClaimLetters::Utils::UserHelper

    def initialize(user, allowed_doctypes = nil)
      @user = user
      @allowed_doctypes = allowed_doctypes || ClaimLetters::DoctypeService.allowed_for_user(user)
      @client = VBMS::Client.from_env_vars(env_name: Settings.vbms.env) unless Rails.env.development? || Rails.env.test?
    end

    def get_letters
      res = nil

      if !Rails.env.development? && !Rails.env.test?
        req = VBMS::Requests::FindDocumentVersionReference.new(ClaimLetters::Utils::UserHelper.file_number(@user))
        res = @client.send_request(req)
      else
        res = ClaimLetterTestData::TEST_DATA
      end
      format_letter_data(res)
    rescue VBMS::FilenumberDoesNotExist
      []
    rescue NoMethodError
      raise Common::Exceptions::BackendServiceException
    end

    def get_letter(document_id)
      letter_details = get_letter_details(document_id)

      if letter_details.nil? || filter_letters(letter_details).nil?
        raise Common::Exceptions::RecordNotFound,
              document_id
      end

      filename = ClaimLetters::Utils::LetterTransformer.filename_with_date(letter_details[:received_at])

      if !Rails.env.development? && !Rails.env.test? && Settings.vsp_environment != 'development'
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

    def filter_letters(document)
      return nil unless @allowed_doctypes.include?(document[:doc_type])

      document
    end

    def format_letter_data(letters)
      # using marshal_dump here because each document is an OpenStruct
      letters = letters.map(&:marshal_dump)
                       .select { |d| ClaimLetters::Utils::LetterTransformer.allowed?(d, @allowed_doctypes) }
                       .select { |d| ClaimLetters::Utils::LetterTransformer.filter_boa(d) }
                       # Issue 96224, consolidating letters' display names upstream
                       .each do |d|
                         d[:type_description] = ClaimLetters::Utils::LetterTransformer
                                                .decorate_description(d[:doc_type])
      end
      # TODO: (rare) Handle nil received_at
      letters.sort_by { |d| d[:received_at] }.reverse
    end

    def get_letter_details(document_id)
      letters = get_letters
      letters.find { |d| d[:document_id] == document_id }
    end
  end
end
