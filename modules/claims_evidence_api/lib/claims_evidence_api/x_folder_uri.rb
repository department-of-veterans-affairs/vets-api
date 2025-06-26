# frozen_string_literal: true

module ClaimsEvidenceApi
  class XFolderUri
    TYPES = {
      'VETERAN' => ['FILENUMBER', 'SSN', 'PARTICIPANT_ID', 'SEARCH', 'EDIPI'],
      'PERSON' => ['PARTICIPANT_ID', 'SEARCH']
    }

    def self.generate(folder_type, identifier_type, id)
      folder_type = validate_folder_type(folder_type)
      identifier_type = validate_identifier_type(identifier_type, folder_type)
      id = validate_id(id, identifier_type)

      "#{folder_type}:#{identifier_type}:#{id}"
    end

    def self.validate(folder_identifier)
      folder_type, identifier_type, id = folder_identifier.split(':', 3)
      generate(folder_type, identifier_type, id)
    end

    private

    def self.validate_folder_type(folder_type)
      folder_type = folder_type.to_s.upcase
      raise ArgumentError unless TYPES.keys.include?(folder_type)

      folder_type
    end

    def self.validate_identifier_type(identifier_type, folder_type)
      identifier_type = identifier_type.to_s.upcase
      raise ArgumentError unless TYPES[folder_type].include?(identifier_type)

      identifier_type
    end

    def self.validate_id(id, identifier_type)
      case identifier_type
      when false
      else
        id
      end
    end
  end

  # end ClaimsEvidenceApi
end
