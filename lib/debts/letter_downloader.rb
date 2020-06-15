module Debts
  class LetterDownloader
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
    ]

    def initialize(file_number)
      @file_number = file_number
      @client = VBMS::Client.from_env_vars(env_name: Settings.vbms.env)
    end

    def list_letters
      records = @client.send_request(
        VBMS::Requests::FindDocumentVersionReference.new(@file_number)
      )

      debts_records = records.find_all do |record|
        DEBTS_DOCUMENT_TYPES.include?(record.doc_type)
      end

      debts_records.map! do |debts_record|
        debts_record.marshal_dump.slice(
          :document_id, :doc_type, :type_description, :received_at
        )
      end
    end
  end
end
