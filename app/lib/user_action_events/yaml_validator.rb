# frozen_string_literal: true

module UserActionEvents
  class YamlValidator
    REQUIRED_KEYS = %w[type description].freeze
    VALID_TYPES = %w[authentication profile].freeze

    def self.validate!(config)
      new(config).validate!
    end

    def initialize(config)
      @config = config
    end

    def validate!
      @config.each do |slug, event_config|
        validate_event!(slug, event_config)
      end
    end

    private

    def validate_event!(slug, event_config)
      raise "Invalid event config for #{slug}" unless event_config.is_a?(Hash)

      REQUIRED_KEYS.each do |key|
        raise "Missing required key '#{key}' for event #{slug}" unless event_config.key?(key)
      end

      unless VALID_TYPES.include?(event_config['type'])
        raise "Invalid type '#{event_config['type']}' for event #{slug}. Valid types: #{VALID_TYPES.join(', ')}"
      end
    end
  end
end
