# frozen_string_literal: true

module SimpleFormsApi
  class CemeteryService
    CEMETERIES_FILE_PATH = Rails.root.join('modules', 'simple_forms_api', 'app', 'json', 'cemeteries.json').freeze

    def self.all
      new.all
    end

    def all
      @cemeteries ||= load_cemeteries
    end

    private

    def load_cemeteries
      return [] unless File.exist?(CEMETERIES_FILE_PATH)

      parsed_data = JSON.parse(File.read(CEMETERIES_FILE_PATH))
      parsed_data['data'] || []
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse cemeteries JSON: #{e.message}"
      []
    rescue => e
      Rails.logger.error "Failed to load cemeteries: #{e.message}"
      []
    end
  end
end
