# frozen_string_literal: true

module IvcChampva
  class FormVersionManager
    # Form version configurations
    FORM_VERSIONS = {
      'vha_10_10d' => {
        current: 'vha_10_10d',
        '2027' => 'vha_10_10d_2027'
      },
      'vha_10_7959c' => {
        current: 'vha_10_7959c',
        '2025' => 'vha_10_7959c_rev2025'
      },
      'vha_10_7959f_2' => {
        current: 'vha_10_7959f_2',
        '2025' => 'vha_10_7959f_2_2025'
      }
    }.freeze

    # Feature flags for form versions
    FORM_VERSION_FLAGS = {
      'vha_10_10d_2027' => 'champva_form_10_10d_2027',
      'vha_10_7959c_rev2025' => 'champva_form_10_7959c_rev2025',
      'vha_10_7959f_2_2025' => 'champva_form_10_7959f_2_2025'
    }.freeze

    # Mapping of new form IDs back to legacy form IDs for S3/metadata compatibility
    LEGACY_MAPPING = {
      'vha_10_10d_2027' => 'vha_10_10d',
      'vha_10_7959c_rev2025' => 'vha_10_7959c',
      'vha_10_7959f_2_2025' => 'vha_10_7959f_2'
    }.freeze

    class << self
      ##
      # Determine which form version to use based on feature flags
      #
      # @param base_form_id [String] The base form ID (e.g., 'vha_10_10d')
      # @param current_user [User, nil] Current user for feature flag evaluation
      # @return [String] The actual form ID to use
      def resolve_form_version(base_form_id, current_user = nil)
        # top-level feature flag check for form versioning
        unless Flipper.enabled?(:champva_form_versioning, current_user) && FORM_VERSIONS.key?(base_form_id)
          return base_form_id
        end

        versions = FORM_VERSIONS[base_form_id]

        # Check for newer versions in reverse chronological order
        versions.each do |version_key, form_id|
          next if version_key == :current

          feature_flag = FORM_VERSION_FLAGS[form_id]
          # check for feature flag for each version
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
        "IvcChampva::#{form_id.titleize.gsub(' ', '')}".constantize
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
    end
  end
end
