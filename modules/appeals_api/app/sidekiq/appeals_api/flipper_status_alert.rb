# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class FlipperStatusAlert
    include Sidekiq::Job

    WARNING_EMOJI = ':warning:'
    TRAFFIC_LIGHT_EMOJI = ':vertical_traffic_light:'

    sidekiq_options retry: 5, unique_for: 30.minutes

    def perform
      features_to_check = load_features_from_config
      if features_to_check.present?
        feature_statuses = Flipper::Utilities::BulkFeatureChecker.enabled_status(features_to_check)
        notify_slack(feature_statuses[:disabled]) unless feature_statuses[:disabled].empty?
      end
    end

    private

    def load_features_from_config
      file_path = AppealsApi::Engine.root.join('config', 'flipper', 'enabled_features.yml')
      feature_hash = read_config_file(file_path)
      return [] if feature_hash.nil?

      env_hash = feature_hash.fetch(Settings.vsp_environment.to_s, []) || []
      features = (env_hash + (feature_hash['common'] || [])).uniq.sort

      if features.empty?
        AppealsApi::Slack::Messager.new(
          {
            warning: "#{WARNING_EMOJI} #{self.class.name} has no configured enabled features.",
            file_path: file_path.to_s
          }
        ).notify!
      end

      features
    end

    def read_config_file(path)
      if File.exist?(path)
        YAML.load_file(path) || {}
      else
        AppealsApi::Slack::Messager.new(
          {
            warning: "#{WARNING_EMOJI} #{self.class.name} features file does not exist.",
            file_path: path.to_s
          }
        ).notify!
        nil
      end
    end

    def notify_slack(disabled_features)
      slack_details = {
        class: self.class.name,
        warning: "#{WARNING_EMOJI} One or more features expected to be enabled were found to be disabled.",
        disabled_flags: "#{TRAFFIC_LIGHT_EMOJI} #{disabled_features.join(', ')} #{TRAFFIC_LIGHT_EMOJI}"
      }
      AppealsApi::Slack::Messager.new(slack_details).notify!
    end
  end
end
