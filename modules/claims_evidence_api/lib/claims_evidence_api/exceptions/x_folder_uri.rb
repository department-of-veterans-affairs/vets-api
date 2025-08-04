# frozen_string_literal: true

module ClaimsEvidenceApi
  # collection of module exceptions
  module Exceptions
    # x_folder_uri exceptions
    module XFolderUri
      # invalid folder type
      class InvalidFolderType < StandardError; end
      # invalid indentifier type for folder type
      class InvalidIdentifierType < StandardError; end
    end

    # end Exceptions
  end

  # end ClaimsEvidenceApi
end
