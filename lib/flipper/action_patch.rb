# frozen_string_literal: true

module FlipperExtensions
  module ActionPatch
    def view(name)
      # Use custom views if enabled in configuration.
      path = custom_views_path.join("#{name}.erb") unless custom_views_path.nil?

      # Fall back to default views if custom views haven't been enabled
      # or if the custom view cannot be found.
      path = views_path.join("#{name}.erb") if path.nil? || !path.exist?

      raise "Template does not exist: #{path}" unless path.exist?

      # rubocop:disable Security/Eval
      eval(Erubi::Engine.new(path.read, escape: true).src)
      # rubocop:enable Security/Eval
    end

    def custom_views_path
      Flipper::UI.configuration.custom_views_path
    end

    # This is where we store the feature descriptions.
    # You can choose to store this where it makes sense for you.
    def yaml_features
      @yaml_features ||= FLIPPER_FEATURE_CONFIG['features']
    end
  end
end
