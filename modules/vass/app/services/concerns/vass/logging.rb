# frozen_string_literal: true

module Vass
  module Logging
    extend ActiveSupport::Concern

    private

    ##
    # Logs a VASS event with standardized format.
    #
    # @param action [String, Symbol] The action being logged
    # @param vass_uuid [String, nil] Optional VASS UUID for traceability
    # @param level [Symbol] Log level (:debug, :info, :warn, :error, :fatal)
    # @param metadata [Hash] Additional metadata to include in the log
    #
    def log_vass_event(action:, vass_uuid: nil, level: :info, **metadata)
      valid_levels = %i[debug info warn error fatal]
      level = :info unless valid_levels.include?(level)

      log_data = {
        service: 'vass',
        action:,
        timestamp: Time.current.iso8601
      }

      # Add component if available (controller name or class name)
      if respond_to?(:controller_name)
        log_data[:controller] = controller_name
      else
        log_data[:component] = self.class.name.demodulize.underscore
      end

      log_data[:vass_uuid] = vass_uuid if vass_uuid
      log_data.merge!(metadata)

      Rails.logger.public_send(level, log_data.to_json)
    rescue JSON::GeneratorError, Encoding::UndefinedConversionError => e
      raise Vass::Errors::AuditLogError, "Failed to write audit log for action=#{action}: #{e.message}"
    end
  end
end
