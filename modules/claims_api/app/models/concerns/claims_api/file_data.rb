# frozen_string_literal: true

require 'json_marshal/marshaller'

module ClaimsApi
  module FileData
    extend ActiveSupport::Concern

    included do
      serialize :file_data, JsonMarshal::Marshaller
      has_kms_key
      has_encrypted :file_data, key: :kms_key, **lockbox_options

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
                           doc_type:,
                           description: }
      end
    end
  end
end
