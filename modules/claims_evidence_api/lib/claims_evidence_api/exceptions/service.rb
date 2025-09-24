# frozen_string_literal: true

module ClaimsEvidenceApi
  module Exceptions
    # service exceptions
    module Service
      # required header is missing
      class UndefinedXFolderURI < StandardError; end
      # intended upload file not found
      class FileNotFound < StandardError; end
      # virus detected
      class VirusFound < StandardError; end
    end

    # end Exceptions
  end

  # end ClaimsEvidenceApi
end
