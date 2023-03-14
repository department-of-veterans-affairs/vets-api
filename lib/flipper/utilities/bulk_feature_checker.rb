# frozen_string_literal: true

module Flipper
  module Utilities
    module BulkFeatureChecker
      # Accepts an array of feature keys (symbol or string format) and returns a result hash of which keys
      # are enabled, disabled, or missing; feature keys are returned in symbol format
      def self.enabled_status(features)
        result = {
          enabled: [],
          disabled: [],
          missing: []
        }
        existing_features = Flipper.features.map(&:name)

        Array(features).map(&:to_sym).each do |feature|
          unless existing_features.include?(feature)
            result[:missing] << feature
            next
          end

          if Flipper.enabled?(feature)
            result[:enabled] << feature
          else
            result[:disabled] << feature
          end
        end

        result
      end
    end
  end
end
