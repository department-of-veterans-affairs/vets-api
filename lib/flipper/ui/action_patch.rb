# frozen_string_literal: true

module Flipper
  module UI
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
        Rails.root.join('lib', 'flipper', 'ui', 'views')
      end
    end
  end
end
