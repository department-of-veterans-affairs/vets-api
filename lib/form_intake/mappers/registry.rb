# frozen_string_literal: true

module FormIntake
  module Mappers
    # Registry for form-specific GCIO mappers
    class Registry
      # Map form IDs to their GCIO mapper class names (as strings for lazy loading)
      # Add new forms here as they're implemented
      FORM_MAPPERS = {
        '21P-0537' => 'FormIntake::Mappers::VBA21p0537Mapper',
        '21P-601' => 'FormIntake::Mappers::VBA21p601Mapper'
      }.freeze

      # Get mapper class for a form type
      # @param form_type [String] Form type (e.g., '21P-601')
      # @return [Class] Mapper class
      # @raise [MappingNotFoundError] if form has no mapper
      def self.mapper_for(form_type)
        class_name = FORM_MAPPERS[form_type]
        raise MappingNotFoundError, "No GCIO mapper defined for form type: #{form_type}" unless class_name

        class_name.constantize
      end

      # Check if form has a mapper
      # @param form_type [String] Form type
      # @return [Boolean]
      def self.mapper?(form_type)
        FORM_MAPPERS.key?(form_type)
      end

      # List all forms with mappers
      # @return [Array<String>] Form type IDs
      def self.mapped_forms
        FORM_MAPPERS.keys
      end
    end

    # Exception raised when form mapper not found
    class MappingNotFoundError < StandardError; end
  end
end
