# frozen_string_literal: true

require 'debt_management_center/debts_service'
require 'debt_management_center/constants'

module DebtsApi
  module Concerns
    module JsonValidatable
      extend ActiveSupport::Concern

      class BaseValidator
        MAX_JSON_SIZE = 500.kilobytes # Prevent DoS from large payloads
        MAX_STRING_FIELD_LENGTH = 1000 # Prevent DoS from extremely long strings
        MAX_JSON_NESTING = 100 # Prevent deeply nested JSON DoS

        # @param max_size [Integer] Maximum size in bytes (default: MAX_JSON_SIZE)
        def self.parse_json_safely(json_string, max_size: MAX_JSON_SIZE)
          raise ArgumentError, 'JSON string cannot be nil' if json_string.nil?

          # Validate size before parsing (prevents DoS)
          if json_string.bytesize > max_size
            raise ArgumentError, "JSON exceeds maximum size of #{max_size / 1024}KB"
          end

          # Parse with explicit nesting limit (default is 100, but being explicit documents security intent)
          JSON.parse(json_string, symbolize_names: true, max_nesting: MAX_JSON_NESTING)
        rescue JSON::ParserError => e
          raise ArgumentError, "Invalid JSON: #{e.message}"
        end

        def self.validate_string_field(value, field_name:, max_length: MAX_STRING_FIELD_LENGTH)
          errors = []

          return errors if value.nil?

          unless value.is_a?(String)
            errors << "#{field_name} must be a string"
            return errors
          end

          if value.bytesize > max_length
            errors << "#{field_name} exceeds maximum length of #{max_length} characters"
          end

          # Sanitize: remove null bytes and control characters (basic XSS prevention)
          if value.include?("\0") || value.match?(/[\x00-\x08\x0B-\x0C\x0E-\x1F]/)
            errors << "#{field_name} contains invalid characters"
          end

          errors
        end

        def self.validate_required_fields(hash, required_fields:, prefix: '')
          errors = []
          return errors unless hash.is_a?(Hash)

          required_fields.each do |field|
            unless hash.key?(field)
              field_name = prefix.present? ? "#{prefix}.#{field}" : field.to_s
              errors << "#{field_name} is missing"
            end
          end

          errors
        end

        def self.validate_against_schema(records, field_name:, required_fields: [], string_fields: [])
          errors = []

          records.each_with_index do |item, index|
            prefix = "#{field_name}[#{index}]"

            unless item.is_a?(Hash)
              errors << "#{prefix} must be an object"
              next
            end

            errors.concat(validate_required_fields(item, required_fields:, prefix:))

            # Validate string fields for security (length limits prevent DoS, control character checks prevent XSS)
            string_fields.each do |field|
              value = item[field] || item[field.to_s]
              next if value.nil?

              field_errors = validate_string_field(value, field_name: "#{prefix}.#{field}")
              errors.concat(field_errors)
            end
          end

          raise ArgumentError, errors.join(', ') if errors.any?
          errors
        end
      end

      class FSRValidator < BaseValidator
        # TODO: Add FSR-specific validation logic
      end

      class DisputeDebtValidator < BaseValidator
        # Extracts composite debt IDs from debt objects that have composite_debt_id field
        # @param debts [Array<Hash>] Array of debt objects with composite_debt_id field (already validated as array)
        # @return [Array<String>] Array of composite debt IDs
        # @raise [ArgumentError] If no composite_debt_ids are found
        def self.extract_composite_debt_ids_from_field(debts)
          composite_debt_ids = debts.filter_map do |debt|
            next unless debt.is_a?(Hash)

            composite_id = debt['composite_debt_id'] || debt[:composite_debt_id] || debt['compositeDebtId'] || debt[:compositeDebtId]
            composite_id if composite_id.present?
          end

          if composite_debt_ids.empty?
            raise ArgumentError, 'At least one composite_debt_id is required in disputes'
          end

          composite_debt_ids
        end

        # Parses and validates dispute metadata JSON
        # @param metadata_string [String] JSON string containing dispute metadata
        # @param user [User] Current user for debt validation
        # @param max_size [Integer] Maximum size in bytes (default: 100KB for disputes)
        # @return [Hash] Parsed and validated metadata
        # @raise [ArgumentError] If validation fails
        def self.parse_and_validate_metadata(metadata_string, user:, max_size: 100.kilobytes)
          parsed = BaseValidator.parse_json_safely(metadata_string, max_size:)

          raise ArgumentError, 'metadata must be a JSON object' unless parsed.is_a?(Hash)
          raise ArgumentError, 'metadata must include a "disputes" key' unless parsed.key?(:disputes)

          disputes = parsed[:disputes]
          required_fields = %i[composite_debt_id deduction_code original_ar current_ar benefit_type dispute_reason]
          string_fields = %i[composite_debt_id deduction_code benefit_type dispute_reason rcvbl_id]
          BaseValidator.validate_against_schema(
            disputes,
            field_name: 'disputes',
            required_fields:,
            string_fields:
        )

          composite_debt_ids = extract_composite_debt_ids_from_field(disputes)
          debts_service = DebtManagementCenter::DebtsService.new(user)
          validate_debt_exist_for_user(composite_debt_ids, debts_service:)

          parsed
        end

        # Validates that composite debt IDs exist and belong to the given user
        # Uses DebtsService#get_debts_by_ids which ensures debts belong to the user via:
        # - User-specific cache key (debts_data_#{user.uuid})
        # - Filtering to only the user's own debts (payeeNumber == '00')
        # @param composite_debt_ids [Array<String>] Array of composite debt IDs to validate
        # @param debts_service [DebtManagementCenter::DebtsService] DebtsService instance for debt validation
        # @raise [ArgumentError] If validation fails (debts not found, don't belong to user, or required debts missing)
        def self.validate_debt_exist_for_user(composite_debt_ids, debts_service:)
          if composite_debt_ids.nil? || composite_debt_ids.empty?
            raise ArgumentError, 'At least one composite debt ID is required'
          end

          found_debts = debts_service.get_debts_by_ids(composite_debt_ids)

          if found_debts.length < composite_debt_ids.length
            missing_count = composite_debt_ids.length - found_debts.length
            raise ArgumentError, "Invalid debt identifiers: #{missing_count} of #{composite_debt_ids.length} debt identifiers not found"
          end
        end
      end

    end
  end
end
