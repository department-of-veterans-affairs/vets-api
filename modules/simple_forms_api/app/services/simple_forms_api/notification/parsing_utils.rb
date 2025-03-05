# frozen_string_literal: true

module SimpleFormsApi
  module Notification
    module ParsingUtils
      def contact_info
        form_mapping = YAML.load_file(
          'modules/simple_forms_api/app/services/simple_forms_api/notification/form_mapping.yml'
        )&.dig(form_number)

        return unless form_mapping

        transformed_data = deep_transform_keys_and_values(form_data)
        mapping_path = find_mapping_path(form_mapping, transformed_data)

        return unless mapping_path

        first_name = dig_value(transformed_data, mapping_path['first_name'])
        email = dig_value(transformed_data, mapping_path['email']) || user&.va_profile_email

        { first_name:, email: }
      end

      private

      def find_mapping_path(form_mapping, form_data)
        return form_mapping if form_mapping.key?('first_name') && form_mapping.key?('email')

        form_mapping.each do |key, value|
          next unless form_data.key?(key)

          # If the value under this key is a hash and its keys
          # match the form_data's value, go deeper
          return find_mapping_path(value[form_data[key]], form_data) if value.is_a?(Hash) && value.key?(form_data[key])
        end

        nil
      end

      def deep_transform_keys_and_values(hash)
        hash.deep_transform_keys { |key| key.to_s.underscore.downcase }
            .transform_values do |value|
              case value
              when Hash
                deep_transform_keys_and_values(value)
              when Array
                value.map { |v| v.is_a?(Hash) ? deep_transform_keys_and_values(v) : v.to_s.underscore.downcase }
              else
                value.to_s.underscore.downcase
              end
            end
      end

      def dig_value(data, keys)
        return data[keys] unless keys.is_a?(Array)

        keys.reduce(data) { |d, key| d.is_a?(Hash) ? d[key] : nil }
      end
    end
  end
end
