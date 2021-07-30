# frozen_string_literal: true

require 'database/key_rotation'
require 'json_marshal/marshaller'

module ClaimsApi
  module FileData
    include Database::KeyRotation
    extend ActiveSupport::Concern

    included do
      attr_encrypted(:file_data, key: Proc.new { |r| r.encryption_key(:file_data) }, marshal: true, marshaler: JsonMarshal::Marshaller)

      def file_name
        file_data['filename']
      end

      def document_type
        file_data['doc_type']
      end

      def description
        file_data['description']
      end

      def set_file_data!(file_data, doc_type, description = nil)
        uploader.store!(file_data)
        self.file_data = { filename: uploader.filename,
                           doc_type: doc_type,
                           description: description }
      end
    end
  end
end
