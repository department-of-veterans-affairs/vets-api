# frozen_string_literal: true

module ClaimsApi
  module ReportRecipientsReader
    extend ActiveSupport::Concern

    def load_recipients(recipient_type)
      recipient_file_path = ClaimsApi::Engine.root.join('config', 'mailinglists', 'mailinglist.yml')
      return [] unless File.exist?(recipient_file_path)

      hash = YAML.load_file(recipient_file_path)
      return [] if hash.nil?

      Array(hash['common']) + Array(hash[recipient_type])
    end
  end
end
