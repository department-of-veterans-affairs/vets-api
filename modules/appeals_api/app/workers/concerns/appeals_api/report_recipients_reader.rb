# frozen_string_literal: true

module AppealsApi
  module ReportRecipientsReader
    def self.load_recipients(recipient_file_name)
      env = Settings.vsp_environment
      hash = YAML.load_file(AppealsApi::Engine.root.join('config', 'mailinglists', "#{recipient_file_name}.yml"))
      env_hash = hash.fetch(env.to_s, [])
      env_hash + hash['common']
    end
  end
end
