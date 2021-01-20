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
          error = if respond_to?(type, true)
                    send type, raw_error
                  else
                    I18n.t('common.exceptions.validation_errors')
                  end
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
      alias object data_type
      alias array data_type

      def enum(error)
        opts = error.dig 'schema', 'enum'
        data = i18n_interpolated :enum, detail: { value: error['data'], enum: opts }
        data[:meta] ||= {}
        data.merge! meta: { available_options: opts }
        data
      end

      def length(error)
        data = i18n_interpolated :length, detail: { value: error['data'] }
        data[:meta] ||= {}
        data[:meta].merge! max_length: error['schema']['maxLength'] if error['schema']['maxLength']
        data[:meta].merge! min_length: error['schema']['minLength'] if error['schema']['minLength']
        data
      end
      alias maxlength length
      alias minlength length

      def range(error)
        data = i18n_interpolated :range, detail: { value: error['data'] }
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

      def array_items(error)
        data = i18n_interpolated :array_items, { detail: { size: error['data'].size } }
        data[:meta] ||= {}
        data[:meta][:received_size] = error['data'].size
        data[:meta][:received_unique_items] = error['data'].size == error['data'].uniq.size
        data[:meta].merge! max_items: error['schema']['maxItems'] if error['schema']['maxItems']
        data[:meta].merge! min_items: error['schema']['minItems'] if error['schema']['minItems']
        data[:meta].merge! unique_items: error['schema']['uniqueItems'] if error['schema']['uniqueItems']
        data
      end
      alias minitems array_items
      alias maxitems array_items
      alias uniqueitems array_items
    end
  end
end
