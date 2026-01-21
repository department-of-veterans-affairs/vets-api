# frozen_string_literal: true

module ClaimsEvidenceApi
  module Exceptions
    # folder_identifier exceptions
    module FolderIdentifier
      # invalid folder type
      class InvalidFolderType < StandardError; end
      # invalid indentifier type for folder type
      class InvalidIdentifierType < StandardError; end
    end

    # end Exceptions
  end

  # end ClaimsEvidenceApi
end
