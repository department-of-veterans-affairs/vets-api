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

      contents = path.read
      compiled = Flipper::UI::Eruby.new(contents)
      compiled.result proc {}.binding
    end

    def custom_views_path
      Flipper::UI.configuration.custom_views_path
    end
  end
end
