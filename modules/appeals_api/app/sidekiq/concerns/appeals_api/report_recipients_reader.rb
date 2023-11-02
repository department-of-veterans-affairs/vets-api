# frozen_string_literal: true

module AppealsApi
  module ReportRecipientsReader
    extend ActiveSupport::Concern

    def load_recipients(recipient_file_name)
      recipient_file_path = AppealsApi::Engine.root.join('config', 'mailinglists', "#{recipient_file_name}.yml")
      hash = read_file(recipient_file_path)
      return [] if hash.nil?

      env_hash = hash.fetch(Settings.vsp_environment.to_s, []) || []
      all_recipients = env_hash + (hash['common'] || [])

      if all_recipients.empty?
        AppealsApi::Slack::Messager.new(
          { warning: ":warning: #{self.class.name} report has no configured recipients",
            recipient_file: recipient_file_path.to_s }
        ).notify!
      end

      all_recipients
    end

    private

    def read_file(recipient_file_path)
      if File.exist?(recipient_file_path)
        YAML.load_file(recipient_file_path) || {}
      else
        AppealsApi::Slack::Messager.new(
          { warning: ":warning: #{self.class.name} recipients file does not exist",
            recipient_file: recipient_file_path.to_s }
        ).notify!
        nil
      end
    end
  end
end
