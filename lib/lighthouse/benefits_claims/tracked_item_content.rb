# frozen_string_literal: true

module BenefitsClaims
  module TrackedItemContent
    # Schema path for tracked item content validation
    SCHEMA_PATH = Rails.root.join('lib', 'lighthouse', 'benefits_claims', 'schemas', 'tracked_item_content.json').to_s

    # Loaded JSON schema for validation (eager-loaded, thread-safe)
    # Removes $schema key to avoid JSON::Schema::SchemaError (gem doesn't support draft-07)
    SCHEMA = begin
      schema = JSON.parse(File.read(SCHEMA_PATH))
      schema.delete('$schema')
      schema.freeze
    rescue Errno::ENOENT => e
      Rails.logger.error("TrackedItemContent schema file not found: #{SCHEMA_PATH} - #{e.message}")
      nil
    rescue JSON::ParserError => e
      Rails.logger.error("TrackedItemContent schema file contains invalid JSON: #{SCHEMA_PATH} - #{e.message}")
      nil
    rescue => e
      Rails.logger.error("Unexpected error loading TrackedItemContent schema: #{e.class} - #{e.message}")
      nil
    end

    # Default values for content entries
    # All fields are optional; these defaults are merged when looking up entries
    DEFAULTS = {
      friendlyName: nil,
      shortDescription: nil,
      activityDescription: nil,
      supportAliases: [],
      canUploadFile: false,
      noActionNeeded: false,
      isDBQ: false,
      isProperNoun: false,
      isSensitive: false,
      noProvidePrefix: false,
      longDescription: nil,
      nextSteps: nil
    }.freeze

    # Path to content overrides JSON file
    CONTENT_PATH = Rails.root.join('lib', 'lighthouse', 'benefits_claims', 'tracked_item_content',
                                   'override_content.json').to_s

    # Content dictionary for tracked item overrides
    # Keys are display names from the Lighthouse API
    # Loaded from JSON file for maintainability (large structured content)
    CONTENT = begin
      JSON.parse(File.read(CONTENT_PATH)).transform_values(&:deep_symbolize_keys).freeze
    rescue Errno::ENOENT => e
      Rails.logger.error("TrackedItemContent content file not found: #{CONTENT_PATH} - #{e.message}")
      {}.freeze
    rescue JSON::ParserError => e
      Rails.logger.error("TrackedItemContent content file contains invalid JSON: #{CONTENT_PATH} - #{e.message}")
      {}.freeze
    rescue => e
      Rails.logger.error("Unexpected error loading TrackedItemContent content: #{e.class} - #{e.message}")
      {}.freeze
    end

    # Pre-computed normalized lookup index for fallback matching
    # Keys are downcased with whitespace around hyphens removed
    # (e.g., "AO - med evid" → "ao-med evid", "RADIATION - medical" → "radiation-medical")
    # Maps normalized keys to original CONTENT values for O(1) lookup
    CONTENT_NORMALIZED = CONTENT.each_with_object({}) do |(key, value), index|
      index[key.downcase.gsub(/\s*-\s*/, '-')] ||= value
    end.freeze

    class << self
      # Validates all CONTENT entries against the JSON schema
      # @return [Hash<String, Array<String>>] Hash mapping display names to validation errors
      def validate_all_entries
        return { 'schema' => ['Schema failed to load'] } if SCHEMA.nil?

        errors = {}

        CONTENT.each do |display_name, entry|
          entry_errors = JSON::Validator.fully_validate(SCHEMA, entry.deep_stringify_keys)
          errors[display_name] = entry_errors if entry_errors.any?
        end

        errors
      end

      # Validates a single entry against the JSON schema
      # @param entry [Hash] The content entry to validate
      # @return [Array<String>] Array of validation error messages
      def validate_entry(entry)
        return ['Schema failed to load'] if SCHEMA.nil?

        JSON::Validator.fully_validate(SCHEMA, entry.deep_stringify_keys)
      end

      # Looks up content override for a given display name or normalized display name
      # Returns entry merged with defaults so all fields are present
      # @param display_name [String] The tracked item display name
      # @return [Hash, nil] The content override with defaults applied, or nil if not found
      def find_by_display_name(display_name)
        entry = CONTENT[display_name]
        return DEFAULTS.merge(entry) if entry

        # Normalize by downcasing and removing spaces around hyphens, then retry against pre-computed index
        normalized = display_name.downcase.gsub(/\s*-\s*/, '-')
        entry = CONTENT_NORMALIZED[normalized]
        return DEFAULTS.merge(entry) if entry

        nil
      end
    end
  end
end
