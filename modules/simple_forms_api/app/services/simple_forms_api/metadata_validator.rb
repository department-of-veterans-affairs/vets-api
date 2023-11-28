# frozen_string_literal: true

module SimpleFormsApi
  class MetadataValidator
    def self.validate(metadata)
      raise ArgumentError, 'veteran first name is missing' unless metadata['veteranFirstName']
      raise ArgumentError, 'veteran first name is not a string' if metadata['veteranFirstName'].class != String

      metadata['veteranFirstName'] = metadata['veteranFirstName'][0..49]
      metadata['veteranFirstName'] = metadata['veteranFirstName'].gsub(/[^a-zA-Z\-\/\s]/, '')

      metadata
    end
  end
end
