# frozen_string_literal: true

require 'sidekiq'
require 'flipper/utilities/bulk_feature_checker'

module VBADocuments
  class FlipperStatusAlert
    include Sidekiq::Worker

    WARNING_EMOJI = ':warning:'
    DISABLED_FLAG_EMOJI = ':vertical_traffic_light:'
    MISSING_FLAG_EMOJI = ':no_entry_sign:'

    sidekiq_options retry: 5, unique_for: 30.minutes

    def perform
      features_to_check = load_features_from_config
      if features_to_check.present?
        @feature_statuses = Flipper::Utilities::BulkFeatureChecker.enabled_status(features_to_check)

        slack_notify unless all_features_enabled?
      end
    end

    private

    def load_features_from_config
      file_path = VBADocuments::Engine.root.join('config', 'flipper', 'enabled_features.yml')
      feature_hash = read_config_file(file_path)
      return [] if feature_hash.nil?

      env_hash = feature_hash.fetch(Settings.vsp_environment.to_s, []) || []

      (env_hash + (feature_hash['common'] || [])).uniq.sort
    end

    def read_config_file(path)
      if File.exist?(path)
        YAML.load_file(path) || {}
      else
        VBADocuments::Slack::Messenger.new(
          {
            warning: "#{WARNING_EMOJI} #{self.class.name} features file does not exist",
            file_path: path.to_s
          }
        ).notify!
        nil
      end
    end

    def all_features_enabled?
      @feature_statuses[:missing].empty? && @feature_statuses[:disabled].empty?
    end

    def slack_notify
      slack_details = {
        class: self.class.name,
        warning: "#{WARNING_EMOJI} One or more features expected to be enabled were found disabled or missing",
        disabled_flags: slack_message(:disabled),
        missing_flags: slack_message(:missing)
      }

      VBADocuments::Slack::Messenger.new(slack_details).notify!
    end

    def slack_message(flag_category)
      if @feature_statuses[flag_category].present?
        emoji = self.class.const_get("#{flag_category.upcase}_FLAG_EMOJI")
        "#{emoji} #{@feature_statuses[flag_category].join(', ')} #{emoji}"
      else
        'None'
      end
    end
  end
end
