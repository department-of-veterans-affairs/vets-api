
module DebtsApi
  module Concerns
    module FormSanitizer
      extend ActiveSupport::Concern
      def sanitize_form_data(form)
        return {} unless form.is_a?(Hash)

        sanitized = form.deep_dup

        sanitized.deep_transform_values do |v|
          v.is_a?(String) ? sanitize_html(v) : v
        end
      end

      private

      def sanitize_html(str)
        ActionController::Base.helpers.sanitize(str, tags: [], attributes: [])
      end
    end
  end
end