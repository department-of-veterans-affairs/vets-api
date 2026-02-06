# frozen_string_literal: true

require 'debt_management_center/debts_service'
require 'debt_management_center/constants'

module DebtsApi
  module Concerns
    module SubmissionValidation
      extend ActiveSupport::Concern

      class BaseValidator
        class FormInvalid < ArgumentError; end

        class << self
          INVALID_ERROR_MESSAGE = 'Invalid request payload schema'

          def validate_form_schema(form, schema_file)
            schema_path = Rails.root.join('lib', 'debt_management_center', 'schemas', schema_file).to_s
            errors = JSON::Validator.fully_validate(schema_path, form)

            log_and_raise_error(errors) if errors.any?
          end

          def log_and_raise_error(errors)
            Rails.logger.error(errors)
            raise FormInvalid, INVALID_ERROR_MESSAGE
          end
        end
      end

      class FSRValidator < BaseValidator
        # TODO: move validation here from fsr_form_builder
      end

      class DisputeDebtValidator < BaseValidator
        class << self
          def validate_form_schema(metadata, user)
            parsed = JSON.parse(metadata)
            disputes = parsed['disputes']
            BaseValidator.validate_form_schema(disputes, 'dispute_debts.json')
            validate_debt_exist_for_user(disputes, user)
            parsed
          end

          private

          def validate_debt_exist_for_user(disputes, user)
            composite_debt_ids = disputes.map { |d| d['composite_debt_id'] }
            log_and_raise_error('At least one composite debt ID is required') if composite_debt_ids.blank?

            debts_service = DebtManagementCenter::DebtsService.new(user)
            found_debts = debts_service.get_debts_by_ids(composite_debt_ids)

            if found_debts.length < composite_debt_ids.length
              missing_count = composite_debt_ids.length - found_debts.length
              log_and_raise_error(
                "Invalid debt identifiers: #{missing_count} of #{composite_debt_ids.length} not found"
              )
            end
          end
        end
      end
    end
  end
end
