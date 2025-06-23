# frozen_string_literal: true

require_relative 'base'

module ClaimsEvidenceApi
  module Service

    # Files API
    class Files < Base

      def create(file_path, payload)
        raise UndefinedXFolderURI unless x_folder_uri?
        raise FileNotFound unless File.exist?(pdf_path)

      end

      def read(uuid)
      end

      def update(uuid, payload)
      end

    end

    # end Service
  end

  # end ClaimsEvidenceApi
end
