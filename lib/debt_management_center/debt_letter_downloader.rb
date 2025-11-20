# frozen_string_literal: true

require 'debt_management_center/debts_service'

module DebtManagementCenter
  class DebtLetterDownloader
    include Vets::SharedLogging

    DEBTS_DOCUMENT_TYPES = %w[
      193
      194
      1213
      1214
      1215
      1216
      1217
      1287
      1334
    ].freeze

    def initialize(user)
      @user = user
      @client = VBMS::Client.from_env_vars(env_name: Settings.vbms.env)
      @service = debts_service
      @vbms_documents = get_vbms_documents
      verify_no_dependent_debts
    end

    def get_letter(document_id)
      verify_letter_in_folder(document_id)

      @client.send_request(
        VBMS::Requests::GetDocumentContent.new(document_id)
      ).content
    end

    def file_name(document_id)
      verify_letter_in_folder(document_id)

      document = @vbms_documents.detect { |doc| doc.document_id == document_id }
      "#{document.type_description} #{document.upload_date.to_formatted_s(:long)}"
    end

    def list_letters
      debts_records = @vbms_documents.find_all do |record|
        DEBTS_DOCUMENT_TYPES.include?(record.doc_type)
      end

      debts_records.map do |debts_record|
        debts_record.marshal_dump.slice(
          :document_id, :doc_type, :type_description, :received_at
        )
      end
    end

    private

    def get_vbms_documents
      @client.send_request(
        VBMS::Requests::FindDocumentVersionReference.new(@service.file_number)
      )
    rescue => e
      log_exception_to_rails(e)
      []
    end

    def debts_service
      DebtManagementCenter::DebtsService.new(@user)
    end

    def verify_no_dependent_debts
      raise Common::Exceptions::Unauthorized if @service.veteran_has_dependent_debts?
    end

    def verify_letter_in_folder(document_id)
      raise Common::Exceptions::Unauthorized unless list_letters.any? do |letter|
        letter[:document_id] == document_id
      end
    end
  end
end
