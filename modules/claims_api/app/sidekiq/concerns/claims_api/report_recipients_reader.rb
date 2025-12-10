# frozen_string_literal: true

module ClaimsApi
  module ReportRecipientsReader
    extend ActiveSupport::Concern

    def load_recipients(recipient_type)
      recipient_file_path = ClaimsApi::Engine.root.join('config', 'mailinglists', 'mailinglist.yml')

      unless File.exist?(recipient_file_path)
        ClaimsApi::Logger.log('ReportRecipientsReader',
                              message: "Recipients file does not exist: #{recipient_file_path}",
                              level: :warn)
        return []
      end

      hash = YAML.safe_load_file(recipient_file_path)

      if hash.nil? || !hash.is_a?(Hash)
        ClaimsApi::Logger.log('ReportRecipientsReader',
                              message: "Recipients file is empty or invalid: #{recipient_file_path}",
                              level: :warn)
        return []
      end

      Array(hash['common']) + Array(hash[recipient_type])
    rescue => e
      ClaimsApi::Logger.log('ReportRecipientsReader',
                            message: "Failed to load recipients from #{recipient_file_path}: #{e.message}",
                            level: :warn)
      []
    end
  end
end
