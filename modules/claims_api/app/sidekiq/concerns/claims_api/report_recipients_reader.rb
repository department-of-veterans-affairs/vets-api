# frozen_string_literal: true

module ClaimsApi
  module ReportRecipientsReader
    extend ActiveSupport::Concern

    def load_recipients(recipient_type)
      recipient_file_path = ClaimsApi::Engine.root.join('config', 'mailinglists', 'mailinglist.yml')
      return [] unless File.exist?(recipient_file_path)

      hash = YAML.safe_load_file(recipient_file_path)
      return [] if hash.nil? || !hash.is_a?(Hash)

      Array(hash['common']) + Array(hash[recipient_type])
    rescue => e
      Rails.logger.error("Failed to load recipients from #{recipient_file_path}: #{e.message}")
      []
    end
  end
end
