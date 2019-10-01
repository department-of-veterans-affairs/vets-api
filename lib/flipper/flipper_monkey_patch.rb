# frozen_string_literal: true

module FlipperExtensions
  module FeaturesMonkeyPatch
    # This is where we store the feature descriptions.  You can choose to store this where it makes sense
    # for you.
    def yaml_features
      @yaml_features ||= FLIPPER_FEATURE_CONFIG['features']
    end
  end
end
