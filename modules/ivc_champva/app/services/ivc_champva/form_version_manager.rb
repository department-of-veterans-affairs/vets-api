# frozen_string_literal: true

module IvcChampva
  class FormVersionManager
    # Form version configurations
    FORM_VERSIONS = {
      'vha_10_10d' => {
        current: 'vha_10_10d',
        '2027' => 'vha_10_10d_2027'
      }
    }.freeze

    # Feature flags for form versions
    FORM_VERSION_FLAGS = {
      'vha_10_10d_2027' => 'form_10_10d_2027_enabled'
    }.freeze

    # Mapping of new form IDs back to legacy form IDs for S3/metadata compatibility
    LEGACY_MAPPING = {
      'vha_10_10d_2027' => 'vha_10_10d'
    }.freeze

    class << self
      ##
      # Determine which form version to use based on feature flags
      #
      # @param base_form_id [String] The base form ID (e.g., 'vha_10_10d')
      # @param current_user [User, nil] Current user for feature flag evaluation
      # @return [String] The actual form ID to use
      def resolve_form_version(base_form_id, current_user = nil)
        return base_form_id unless FORM_VERSIONS.key?(base_form_id)

        versions = FORM_VERSIONS[base_form_id]

        # Check for newer versions in reverse chronological order
        versions.each do |version_key, form_id|
          next if version_key == :current

          feature_flag = FORM_VERSION_FLAGS[form_id]
          if feature_flag && Flipper.enabled?(feature_flag, current_user)
            Rails.logger.info("IVC ChampVA Forms - Using form version #{form_id} for #{base_form_id}")
            return form_id
          end
        end

        # Fall back to current version
        versions[:current]
      end

      ##
      # Get the legacy form ID for S3/metadata compatibility
      #
      # @param form_id [String] The actual form ID being used
      # @return [String] The legacy form ID for backwards compatibility
      def get_legacy_form_id(form_id)
        LEGACY_MAPPING.fetch(form_id, form_id)
      end

      ##
      # Get the appropriate form class for a given form ID
      #
      # @param form_id [String] The form ID
      # @return [Class] The form model class
      def get_form_class(form_id)
        case form_id
        when 'vha_10_10d_2027'
          IvcChampva::VHA1010d2027
        else
          "IvcChampva::#{form_id.titleize.gsub(' ', '')}".constantize
        end
      end

      ##
      # Create a form instance with version resolution
      #
      # @param base_form_id [String] The base form ID
      # @param data [Hash] Form data
      # @param current_user [User, nil] Current user for feature flag evaluation
      # @return [Object] Form instance
      def create_form_instance(base_form_id, data, current_user = nil)
        actual_form_id = resolve_form_version(base_form_id, current_user)
        form_class = get_form_class(actual_form_id)
        form_class.new(data)
      end

      ##
      # Check if a form ID is a versioned form that needs legacy mapping
      #
      # @param form_id [String] The form ID to check
      # @return [Boolean] True if this is a versioned form
      def versioned_form?(form_id)
        LEGACY_MAPPING.key?(form_id)
      end

      ##
      # Get all available versions for a base form
      #
      # @param base_form_id [String] The base form ID
      # @return [Hash] Available versions
      def get_available_versions(base_form_id)
        FORM_VERSIONS.fetch(base_form_id, {})
      end

      ##
      # Add a new form version configuration
      #
      # @param base_form_id [String] The base form ID
      # @param version_key [String] Version identifier (e.g., '2027')
      # @param versioned_form_id [String] The actual form ID for this version
      # @param feature_flag [String] Feature flag name
      # @param legacy_form_id [String, nil] Legacy form ID for backwards compatibility
      def register_form_version(base_form_id, version_key, versioned_form_id, feature_flag, legacy_form_id = nil)
        FORM_VERSIONS[base_form_id] ||= { current: base_form_id }
        FORM_VERSIONS[base_form_id][version_key] = versioned_form_id
        FORM_VERSION_FLAGS[versioned_form_id] = feature_flag
        LEGACY_MAPPING[versioned_form_id] = legacy_form_id if legacy_form_id
      end
    end
  end
end
