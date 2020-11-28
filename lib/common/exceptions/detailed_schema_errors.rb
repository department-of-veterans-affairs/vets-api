# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions
    class DetailedSchemaErrors < BaseError
      # Expects array of JSONSchemer errors
      def initialize(raw_schema_errors)
        @raw_errors = raw_schema_errors
        raise TypeError, 'the resource provided has no errors' if raw_schema_errors.blank?
      end

      def errors
        @raw_errors.map do |raw_error|
          type = raw_error['type'].downcase
          pointer = raw_error['data_pointer'].presence || '/'
          error = send type, raw_error
          error.merge! source: { pointer: pointer }
          SerializableError.new error
        end
      end

      private

      def i18n_interpolated(path, options = {})
        merge_values = Hash[options.map { |attr, opts| [attr, i18n_field("#{path}.#{attr}", opts)] }]
        i18n_data[path].merge(merge_values)
      end

      def data_type(_error)
        i18n_interpolated :data_type, detail: { data_type: __callee__ }
      end
      alias boolean data_type
      alias integer data_type
      alias number data_type
      alias string data_type

      def enum(error)
        opts = error.dig 'schema', 'enum'
        data = i18n_interpolated :enum, detail: { value: error['data'], enum: opts }
        data[:meta] ||= {}
        data.merge! meta: { available_options: opts }
        data
      end

      def length(error)
        data = i18n_interpolated :length
        data[:meta] ||= {}
        data[:meta].merge! max_length: error['schema']['maxLength'] if error['schema']['maxLength']
        data[:meta].merge! min_length: error['schema']['minLength'] if error['schema']['minLength']
        data
      end
      alias maxlength length
      alias minlength length

      def range(error)
        data = i18n_interpolated :range
        data[:meta] ||= {}
        data[:meta].merge! maximum: error['schema']['maximum'] if error['schema']['maximum']
        data[:meta].merge! minimum: error['schema']['minimum'] if error['schema']['minimum']
        data
      end
      alias maximum range
      alias minimum range

      def pattern(error)
        regex = error.dig 'schema', 'pattern'
        data = i18n_interpolated :pattern, detail: { value: error['data'], regex: regex }
        data.merge! meta: { regex: regex }
        data
      end

      def required(error)
        data = i18n_interpolated :required
        data.merge! meta: { missing_fields: error['details']['missing_keys'] }
        data
      end

      def schema(_error)
        data = i18n_interpolated :schema
        data
      end
    end
  end
end
