# frozen_string_literal: true

module Common
  module Exceptions
    # Base error class all others inherit from
    class BaseError < StandardError
      def errors
        raise NotImplementedError, 'Subclass of Error must implement errors method'
      end

      def status_code
        return if errors&.first.blank?
        return errors.first[:status]&.to_i if errors.first.is_a?(Hash)

        errors&.first&.status&.to_i
      end

      def message
        i18n_data[:title]
      end

      # This determines how the exception should get logged to Sentry
      # in adddition to available types from Sentry: 'warn', 'info', 'error' there is 'none' to not log to Sentry at all
      def sentry_type
        i18n_data[:sentry_type].presence || 'error'
      end

      def log_to_sentry?
        sentry_type != 'none'
      end

      private

      def i18n_key
        "common.exceptions.#{self.class.name.split('::').last.underscore}"
      end

      def i18n_data
        I18n.t(i18n_key)
      end

      def i18n_field(attribute, options)
        I18n.t("#{i18n_key}.#{attribute}", **options)
      rescue
        nil
      end

      def i18n_interpolated(options = {})
        merge_values = options.to_h { |attribute, opts| [attribute, i18n_field(attribute, opts)] }
        i18n_data.merge(merge_values)
      end
    end
  end
end
