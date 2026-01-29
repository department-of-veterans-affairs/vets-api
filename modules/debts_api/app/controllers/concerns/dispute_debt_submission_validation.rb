# frozen_string_literal: true

require 'debt_management_center/debts_service'
require 'debt_management_center/constants'

module DebtsApi
  module Concerns
    module DisputeDebtSubmissionValidation
      extend ActiveSupport::Concern

      class BaseValidator
        class << self
          MAX_JSON_SIZE = 100.kilobytes # Prevent DoS from large payloads
          MAX_STRING_FIELD_LENGTH = 1000 # Prevent DoS from extremely long strings
          MAX_JSON_NESTING = 100 # Prevent deeply nested JSON DoS

          INVALID_REQUEST_PAYLOAD = 'Invalid request payload'

          def parse_json_safely(json_string, max_size: MAX_JSON_SIZE)
            if json_string.nil?
              log_and_raise_error('JSON string was nil')
            end

            if json_string.bytesize > max_size
              log_and_raise_error("JSON exceeds maximum size of #{max_size / 1024}KB")
            end

            # Parse with explicit nesting limit (default is 100, but being explicit documents security intent)
            JSON.parse(json_string, symbolize_names: true, max_nesting: MAX_JSON_NESTING)
          rescue JSON::ParserError => e
            log_and_raise_error(e.message)
          end

          def validate_field_schema(records, field_name:, required_fields: [], string_fields: [])
            invalid_prefixes = []
            
            records.each_with_index do |item, index|
              prefix = "#{field_name}[#{index}]"

              unless item.is_a?(Hash)
                invalid_prefixes << "#{prefix} must be an object"
                next
              end
              
              log_and_raise_error("Invalid prefixes: #{invalid_prefixes.join(', ')}") if invalid_prefixes.any?

              validate_required_fields(item, required_fields:, prefix:)
              validate_string_fields(item, string_fields:, prefix:)
            end
          end

          private

          def validate_string_format(value, field_name:, max_length: MAX_STRING_FIELD_LENGTH)
            unless value.is_a?(String)
              log_and_raise_error("#{field_name} must be a string")
            end

            exceeds_maximum_length = value.bytesize > max_length
            invalid_characters = value.match?(/[\x00-\x1F]/)
            
            if exceeds_maximum_length || invalid_characters
              message = exceeds_maximum_length ? 
                "#{field_name} exceeds maximum length of #{max_length} characters" : 
                "#{field_name} contains invalid characters"
              log_and_raise_error(message)
            end
          end

          def validate_required_fields(hash, required_fields:, prefix: '')
            log_and_raise_error('hash must be an object') unless hash.is_a?(Hash)

            missing_fields = []
            required_fields.each do |field|
              unless hash.key?(field)
                field_name = prefix.present? ? "#{prefix}.#{field}" : field.to_s
                missing_fields << "#{field_name} is missing"
              end
            end

            log_and_raise_error("Missing fields: #{missing_fields.join(', ')}")
          end

          def validate_string_fields(item, string_fields:, prefix:)
            string_fields.each do |field|
              value = item[field] || item[field.to_s]
              next if value.nil?

              validate_string_format(value, field_name: "#{prefix}.#{field}")
            end
          end

          def log_and_raise_error(message)
            Rails.logger.warn(message)
            raise ArgumentError, INVALID_REQUEST_PAYLOAD
          end
        end
      end

      class FSRValidator < BaseValidator
        # TODO: Add FSR-specific validation logic
      end

      class DisputeDebtValidator < BaseValidator
        class << self
          def parse_and_validate_metadata(metadata_string, user:, max_size: 100.kilobytes)
            parsed = BaseValidator.parse_json_safely(metadata_string, max_size:)

            raise ArgumentError, 'metadata must be a JSON object' unless parsed.is_a?(Hash)
            raise ArgumentError, 'metadata must include a "disputes" key' unless parsed.key?(:disputes)

            disputes = parsed[:disputes]
            required_fields = %i[composite_debt_id deduction_code original_ar current_ar benefit_type dispute_reason]
            string_fields = %i[composite_debt_id deduction_code benefit_type dispute_reason rcvbl_id]
            BaseValidator.validate_field_schema(
              disputes,
              field_name: 'disputes',
              required_fields:,
              string_fields:
            )

            composite_debt_ids = extract_composite_debt_ids_from_field(disputes)
            validate_debt_exist_for_user(composite_debt_ids, user:)

            parsed
          end

          private

          def extract_composite_debt_ids_from_field(debts)
            composite_debt_ids = debts.map.with_index do |debt, index|
              raise ArgumentError, "disputes[#{index}] must be an object" unless debt.is_a?(Hash)

              debt[:composite_debt_id]
            end

            raise ArgumentError, 'At least one composite_debt_id is required in disputes' if composite_debt_ids.empty?
            composite_debt_ids
          end

          def validate_debt_exist_for_user(composite_debt_ids, user:)
            if composite_debt_ids.nil? || composite_debt_ids.empty?
              raise ArgumentError, 'At least one composite debt ID is required'
            end

            debts_service = DebtManagementCenter::DebtsService.new(user)
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
end
