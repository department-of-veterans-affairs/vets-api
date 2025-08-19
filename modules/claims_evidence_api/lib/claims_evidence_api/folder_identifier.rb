# frozen_string_literal: true

require 'claims_evidence_api/exceptions/folder_identifier'

module ClaimsEvidenceApi
  # value used in request header to identify a folder location
  class FolderIdentifier
    include ClaimsEvidenceApi::Exceptions::FolderIdentifier

    # valid associated types
    TYPES = {
      'VETERAN' => %w[FILENUMBER SSN PARTICIPANT_ID SEARCH ICN EDIPI],
      'PERSON' => %w[PARTICIPANT_ID SEARCH]
    }.freeze

    # validate, conform, and create the identifier to be used
    # @see TYPES
    #
    # Header Format: folder-type:identifier-type:ID
    # eg. VETERAN:FILENUMBER:987267855
    #
    # @param folder_type [String] the folder type
    # @param identifier_type [String] the identifier type
    # @param id [String|Number] the identifier type value
    #
    # @raise [ArgumentError] if an argument is not valid for its type
    #
    # @return [String] a valid x_folder_uri header value
    def self.generate(folder_type, identifier_type, id)
      folder_type = validate_folder_type(folder_type)
      identifier_type = validate_identifier_type(identifier_type, folder_type)
      id = validate_id(id, identifier_type)

      "#{folder_type}:#{identifier_type}:#{id}"
    end

    # check if an assembled folder_identifier is valid
    #
    # @param folder_identifier [String] an x_folder_uri
    #
    # @see #generate
    def self.validate(folder_identifier)
      folder_type, identifier_type, id = folder_identifier.split(':', 3)
      generate(folder_type, identifier_type, id)
    end

    # validate the folder_type
    #
    # @param folder_type [String] the folder type
    #
    # @raise [ArgumentError] if an argument is not valid for its type
    #
    # @return [String] the conformed folder_type
    def self.validate_folder_type(folder_type)
      folder_type = folder_type.to_s.upcase
      raise InvalidFolderType unless TYPES.keys.include?(folder_type)

      folder_type
    end

    # validate the indentifier type against the folder type
    #
    # @param identifier_type [String] the identifier type
    # @param folder_type [String] the folder type
    #
    # @raise [ArgumentError] if an argument is not valid for its type
    #
    # @return [String] the conformed identifier_type
    def self.validate_identifier_type(identifier_type, folder_type)
      identifier_type = identifier_type.to_s.upcase
      raise InvalidIdentifierType unless TYPES[folder_type].include?(identifier_type)

      identifier_type
    end

    # validate the provided id value
    #
    # @param id [String|Number] the identifier type value
    # @param identifier_type [String] the identifier type
    #
    # @raise [ArgumentError] if an argument is not valid for its type
    #
    # @return [String|Number] the conformed id value
    def self.validate_id(id, identifier_type)
      # TODO: conform and validate id values; future ticket
      case identifier_type
      when 'FILENUMBER', 'SSN', 'PARTICIPANT_ID', 'EDIPI'
        id.to_s
      else
        id
      end
    end
  end

  # end ClaimsEvidenceApi
end
