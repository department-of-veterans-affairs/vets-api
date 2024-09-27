# frozen_string_literal: true

require 'reports/uploader'

module SimpleFormsApi
  module S3
    class Utils
      private

      def assign_instance_variables(defaults)
        defaults.each do |key, value|
          instance_var = instance_variable_get("@#{key}")

          instance_variable_set("@#{key}", value) if value && instance_var.to_s.empty?
        end
      end
    end
  end
end
