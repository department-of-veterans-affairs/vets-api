# frozen_string_literal: true

module ClaimsEvidenceApi
  module XFolderUri
    TYPES = {
      'VETERAN' => ['FILENUMBER', 'SSN', 'PARTICIPANT_ID', 'SEARCH', 'EDIPI'],
      'PERSON' => ['PARTICIPANT_ID', 'SEARCH']
    }

    def generate(folder_type, identifier_type, id)
      folder_type = validate_folder_type(folder_type)
      identifier_type = validate_identifier_type(identifier_type, folder_type)
      id = validate_id(id, identifier_type)

      "#{folder_type}:#{identifier_type}:#{id}"
    end

    def validate(folder_identifier)
      folder_type, identifier_type, id = folder_identifier.split(':')
      generate(folder_type, identifier_type, id)
    end

    private

    def validate_folder_type(folder_type)
      folder_type = folder_type.to_s.upcase
      raise ArgumentError unless TYPES.keys.include?(folder_type)

      folder_type
    end

    def validate_identifier_type(identifier_type, folder_type)
      identifier_type = identifier_type.to_s.upcase
      raise ArgumentError unless TYPES[folder_type].include?(identifier_type)

      identifier_type
    end

    def validate_id(id, identifier_type)
      case identifier_type
      else
        id
      end
    end
  end

  # end ClaimsEvidenceApi
end
