# frozen_string_literal: true

module DebtsApi
  class V0::DigitalDispute
    # Currently just provides the stats key constant used by the controller
    # In the future will handle forwarding to DMC / storage

    STATS_KEY = 'api.digital_dispute_submission'

    def validate_files_present
      if files.blank? || !files.is_a?(Array) || files.empty?
        raise NoFilesProvidedError,
              'at least one file is required'
      end
    end

    def validate_files
      errors = []

      files.each_with_index do |file, index|
        file_index = index + 1

        errors << "File #{file_index} must be a PDF" unless file.content_type == ACCEPTED_CONTENT_TYPE

        errors << "File #{file_index} is too large (maximum is 1MB)" if file.size > MAX_FILE_SIZE
      end

      raise InvalidFileTypeError, errors.join(', ') if errors.any?
    end

    def sanitize_filename(filename)
      name = File.basename(filename)
      name = name.tr(':', '_')
      name.gsub(/[.](?=.*[.])/, '')
    end
  end
end