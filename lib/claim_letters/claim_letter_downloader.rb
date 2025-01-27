# frozen_string_literal: true

require 'claim_letters/claim_letter_test_data'

module ClaimStatusTool
  class ClaimLetterDownloader
    FILENAME = 'ClaimLetter'
    DOCTYPE_TO_TYPE_DESCRIPTION = {
      '27' => 'Board decision',
      '34' => 'Request for specific evidence or information',
      '184' => 'Claim decision (or other notification, like Intent to File)',
      '408' => 'Notification: Exam with VHA has been scheduled',
      '700' => 'Request for specific evidence or information',
      '704' => 'List of evidence we may need ("5103 notice")',
      '706' => 'List of evidence we may need ("5103 notice")',
      '858' => 'List of evidence we may need ("5103 notice")',
      '859' => 'Request for specific evidence or information',
      '864' => 'Copy of request for medical records sent to a non-VA provider',
      '942' => 'Final notification: Request for specific evidence or information',
      '1605' => 'Copy of request for non-medical records sent to a non-VA organization'
    }.freeze

    def initialize(user, allowed_doctypes = default_allowed_doctypes)
      @user = user
      @client = VBMS::Client.from_env_vars(env_name: Settings.vbms.env) unless Rails.env.development? || Rails.env.test?
      @allowed_doctypes = allowed_doctypes
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
    rescue NoMethodError
      raise Common::Exceptions::BackendServiceException
    end

    def get_letter(document_id)
      letter_details = get_letter_details(document_id)

      if letter_details.nil? || filter_letters(letter_details).nil?
        raise Common::Exceptions::RecordNotFound,
              document_id
      end

      filename = filename_with_date(letter_details[:received_at])

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

    # 27: Board Of Appeals Decision Letter
    # 34: Correspondence
    # 184: Notification Letter (e.g. VA 20-8993, VA 21-0290, PCGL)
    # 408: VA Examination Letter
    # 700: MAP-D Development letter
    # 704: Standard 5103 Notice
    # 706: 5103/DTA Letter
    # 858: Custom 5103 Notice
    # 859: Subsequent Development letter
    # 864: General Records Request (Medical)
    # 942: Final Attempt Letter
    # 1605: General Records Request (Non-Medical)
    def default_allowed_doctypes
      doctypes = %w[184]
      doctypes << '27' if Flipper.enabled?(:cst_include_ddl_boa_letters, @current_user)
      doctypes << '704' if Flipper.enabled?(:cst_include_ddl_5103_letters, @current_user)
      doctypes << '706' if Flipper.enabled?(:cst_include_ddl_5103_letters, @current_user)
      doctypes << '858' if Flipper.enabled?(:cst_include_ddl_5103_letters, @current_user)
      doctypes << '34' if Flipper.enabled?(:cst_include_ddl_sqd_letters, @current_user)
      doctypes << '408' if Flipper.enabled?(:cst_include_ddl_sqd_letters, @current_user)
      doctypes << '700' if Flipper.enabled?(:cst_include_ddl_sqd_letters, @current_user)
      doctypes << '859' if Flipper.enabled?(:cst_include_ddl_sqd_letters, @current_user)
      doctypes << '864' if Flipper.enabled?(:cst_include_ddl_sqd_letters, @current_user)
      doctypes << '942' if Flipper.enabled?(:cst_include_ddl_sqd_letters, @current_user)
      doctypes << '1605' if Flipper.enabled?(:cst_include_ddl_sqd_letters, @current_user)
      doctypes
    end

    def file_number
      # In staging, some users don't have a participant_id
      return @user.ssn if @user.participant_id.blank?

      bgs_file_number = BGS::People::Request.new.find_person_by_participant_id(user: @user).file_number
      bgs_file_number.presence || @user.ssn
    end

    def filter_letters(document)
      return nil unless @allowed_doctypes.include?(document[:doc_type])

      document
    end

    def filter_boa_letters(document)
      # 27: Board Of Appeals Decision Letter
      return false if document[:doc_type] == '27' && Time.zone.today - document[:received_at] < 2

      document
    end

    def format_letter_data(docs)
      # using marshal_dump here because each document is an OpenStruct
      letters = docs.map { |d| filter_letters(d.marshal_dump) }.compact
      letters = letters.select { |d| filter_boa_letters(d) }
      # Issue 96224, consolidating letters' display names upstream
      letters.each { |d| d[:type_description] = DOCTYPE_TO_TYPE_DESCRIPTION[d[:doc_type]] }
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
