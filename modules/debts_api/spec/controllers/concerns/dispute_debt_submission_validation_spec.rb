# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DebtsApi::Concerns::DisputeDebtSubmissionValidation do
  describe 'BaseValidator' do
    describe '.parse_json_safely' do
      context 'with valid JSON' do
        it 'parses JSON string successfully' do
          json_string = '{"key": "value"}'
          result = described_class::BaseValidator.parse_json_safely(json_string)
          expect(result).to eq({ key: 'value' })
        end

        it 'symbolizes keys' do
          json_string = '{"composite_debt_id": "123"}'
          result = described_class::BaseValidator.parse_json_safely(json_string)
          expect(result).to have_key(:composite_debt_id)
        end
      end

      context 'with nil JSON string' do
        it 'raises ArgumentError' do
          expect do
            described_class::BaseValidator.parse_json_safely(nil)
          end.to raise_error(ArgumentError, described_class::BaseValidator::INVALID_REQUEST_PAYLOAD)
        end

        it 'logs a warning' do
          expect(Rails.logger).to receive(:warn).with('JSON string was nil')
          expect do
            described_class::BaseValidator.parse_json_safely(nil)
          end.to raise_error(ArgumentError)
        end
      end

      context 'with JSON exceeding max size' do
        it 'raises ArgumentError' do
          large_json = '{"key": "' + ('x' * 101.kilobytes) + '"}'
          expect do
            described_class::BaseValidator.parse_json_safely(large_json)
          end.to raise_error(ArgumentError, described_class::BaseValidator::INVALID_REQUEST_PAYLOAD)
        end
      end

      context 'with invalid JSON' do
        it 'raises ArgumentError' do
          invalid_json = '{invalid json}'
          expect do
            described_class::BaseValidator.parse_json_safely(invalid_json)
          end.to raise_error(ArgumentError, described_class::BaseValidator::INVALID_REQUEST_PAYLOAD)
        end
      end

      context 'with custom max size' do
        it 'respects custom max size parameter' do
          json_string = '{"key": "' + ('x' * 50.kilobytes) + '"}'
          expect do
            described_class::BaseValidator.parse_json_safely(json_string, max_size: 10.kilobytes)
          end.to raise_error(ArgumentError)
        end
      end
    end

    describe '.validate_field_schema' do
      let(:valid_records) do
        [
          { composite_debt_id: '123', deduction_code: '71', dispute_reason: 'Test reason' },
          { composite_debt_id: '456', deduction_code: '72', dispute_reason: 'Another reason' }
        ]
      end

      context 'with valid records' do
        it 'validates successfully' do
          expect do
            described_class::BaseValidator.validate_field_schema(
              valid_records,
              field_name: 'disputes',
              required_fields: [:composite_debt_id],
              string_fields: [:composite_debt_id, :dispute_reason]
            )
          end.not_to raise_error
        end
      end

      context 'with non-array input' do
        it 'raises ArgumentError' do
          expect do
            described_class::BaseValidator.validate_field_schema(
              { not: 'an array' },
              field_name: 'disputes',
              required_fields: [:composite_debt_id]
            )
          end.to raise_error(ArgumentError, described_class::BaseValidator::INVALID_REQUEST_PAYLOAD)
        end
      end

      context 'with non-hash items' do
        it 'raises ArgumentError' do
          invalid_records = ['not a hash', { composite_debt_id: '123' }]
          expect do
            described_class::BaseValidator.validate_field_schema(
              invalid_records,
              field_name: 'disputes',
              required_fields: [:composite_debt_id]
            )
          end.to raise_error(ArgumentError, described_class::BaseValidator::INVALID_REQUEST_PAYLOAD)
        end
      end

      context 'with missing required fields' do
        it 'raises ArgumentError' do
          records_missing_field = [{ composite_debt_id: '123' }]
          expect do
            described_class::BaseValidator.validate_field_schema(
              records_missing_field,
              field_name: 'disputes',
              required_fields: [:composite_debt_id, :deduction_code]
            )
          end.to raise_error(ArgumentError, described_class::BaseValidator::INVALID_REQUEST_PAYLOAD)
        end
      end

      context 'with string fields exceeding max length' do
        it 'raises ArgumentError' do
          long_string = 'x' * 1001
          records_with_long_string = [{ composite_debt_id: long_string, deduction_code: '71' }]
          expect do
            described_class::BaseValidator.validate_field_schema(
              records_with_long_string,
              field_name: 'disputes',
              required_fields: [:composite_debt_id],
              string_fields: [:composite_debt_id]
            )
          end.to raise_error(ArgumentError, described_class::BaseValidator::INVALID_REQUEST_PAYLOAD)
        end
      end

      context 'with string fields containing control characters' do
        it 'raises ArgumentError' do
          string_with_control = "test\x00null"
          records_with_control = [{ composite_debt_id: '123', dispute_reason: string_with_control }]
          expect do
            described_class::BaseValidator.validate_field_schema(
              records_with_control,
              field_name: 'disputes',
              required_fields: [:composite_debt_id],
              string_fields: [:dispute_reason]
            )
          end.to raise_error(ArgumentError, described_class::BaseValidator::INVALID_REQUEST_PAYLOAD)
        end
      end
    end
  end

  describe 'DisputeDebtValidator' do
    let(:user) { build(:user, :loa3) }
    let(:valid_metadata) do
      {
        disputes: [
          {
            composite_debt_id: '71166',
            deduction_code: '71',
            original_ar: 166.67,
            current_ar: 120.4,
            benefit_type: 'CH33 Books, Supplies/MISC EDU',
            dispute_reason: "I don't think I owe this debt to VA"
          }
        ]
      }.to_json
    end

    let(:mock_debts_service) { instance_double(DebtManagementCenter::DebtsService) }
    let(:mock_debt) { { 'compositeDebtId' => '71166', 'deductionCode' => '71' } }

    before do
      allow(DebtManagementCenter::DebtsService).to receive(:new).with(user).and_return(mock_debts_service)
      allow(mock_debts_service).to receive(:get_debts_by_ids).and_return([mock_debt])
    end

    describe '.parse_and_validate_metadata' do
      context 'with valid metadata' do
        it 'returns parsed metadata' do
          result = described_class::DisputeDebtValidator.parse_and_validate_metadata(
            valid_metadata,
            user: user
          )
          expect(result).to be_a(Hash)
          expect(result[:disputes]).to be_an(Array)
          expect(result[:disputes].first[:composite_debt_id]).to eq('71166')
        end

        it 'validates debt existence' do
          expect(mock_debts_service).to receive(:get_debts_by_ids).with(['71166'])
          described_class::DisputeDebtValidator.parse_and_validate_metadata(
            valid_metadata,
            user: user
          )
        end
      end

      context 'with invalid JSON' do
        it 'raises ArgumentError' do
          expect do
            described_class::DisputeDebtValidator.parse_and_validate_metadata(
              '{invalid json}',
              user: user
            )
          end.to raise_error(ArgumentError, described_class::BaseValidator::INVALID_REQUEST_PAYLOAD)
        end
      end

      context 'when metadata is not a JSON object' do
        it 'raises ArgumentError' do
          expect do
            described_class::DisputeDebtValidator.parse_and_validate_metadata(
              '["not", "an", "object"]',
              user: user
            )
          end.to raise_error(ArgumentError, 'metadata must be a JSON object')
        end
      end

      context 'when metadata is missing disputes key' do
        it 'raises ArgumentError' do
          metadata_without_disputes = { other_key: 'value' }.to_json
          expect do
            described_class::DisputeDebtValidator.parse_and_validate_metadata(
              metadata_without_disputes,
              user: user
            )
          end.to raise_error(ArgumentError, 'metadata must include a "disputes" key')
        end
      end

      context 'when disputes is not an array' do
        it 'raises ArgumentError' do
          metadata_with_non_array = { disputes: { not: 'an array' } }.to_json
          expect do
            described_class::DisputeDebtValidator.parse_and_validate_metadata(
              metadata_with_non_array,
              user: user
            )
          end.to raise_error(ArgumentError, described_class::BaseValidator::INVALID_REQUEST_PAYLOAD)
        end
      end

      context 'when dispute item is not a hash' do
        it 'raises ArgumentError' do
          metadata_with_invalid_item = { disputes: ['not a hash'] }.to_json
          expect do
            described_class::DisputeDebtValidator.parse_and_validate_metadata(
              metadata_with_invalid_item,
              user: user
            )
          end.to raise_error(ArgumentError, 'disputes[0] must be an object')
        end
      end

      context 'when required fields are missing' do
        it 'raises ArgumentError' do
          incomplete_metadata = {
            disputes: [
              {
                composite_debt_id: '71166'
                # missing other required fields
              }
            ]
          }.to_json

          expect do
            described_class::DisputeDebtValidator.parse_and_validate_metadata(
              incomplete_metadata,
              user: user
            )
          end.to raise_error(ArgumentError, described_class::BaseValidator::INVALID_REQUEST_PAYLOAD)
        end
      end

      context 'when no composite_debt_ids are found' do
        it 'raises ArgumentError' do
          metadata_without_ids = {
            disputes: [
              {
                deduction_code: '71',
                original_ar: 166.67,
                current_ar: 120.4,
                benefit_type: 'CH33',
                dispute_reason: 'Test'
              }
            ]
          }.to_json

          expect do
            described_class::DisputeDebtValidator.parse_and_validate_metadata(
              metadata_without_ids,
              user: user
            )
          end.to raise_error(ArgumentError, 'At least one composite_debt_id is required in disputes')
        end
      end

      context 'when debts do not exist for user' do
        it 'raises ArgumentError' do
          allow(mock_debts_service).to receive(:get_debts_by_ids).and_return([])

          expect do
            described_class::DisputeDebtValidator.parse_and_validate_metadata(
              valid_metadata,
              user: user
            )
          end.to raise_error(ArgumentError, /Invalid debt identifiers/)
        end
      end

      context 'when some debts are missing' do
        it 'raises ArgumentError with count' do
          allow(mock_debts_service).to receive(:get_debts_by_ids).and_return([mock_debt])

          metadata_with_multiple = {
            disputes: [
              {
                composite_debt_id: '71166',
                deduction_code: '71',
                original_ar: 166.67,
                current_ar: 120.4,
                benefit_type: 'CH33',
                dispute_reason: 'Test'
              },
              {
                composite_debt_id: '99999',
                deduction_code: '72',
                original_ar: 100.0,
                current_ar: 100.0,
                benefit_type: 'CH33',
                dispute_reason: 'Test'
              }
            ]
          }.to_json

          expect do
            described_class::DisputeDebtValidator.parse_and_validate_metadata(
              metadata_with_multiple,
              user: user
            )
          end.to raise_error(ArgumentError, /Invalid debt identifiers: 1 of 2 debt identifiers not found/)
        end
      end

      context 'with optional rcvbl_id field' do
        it 'validates successfully' do
          metadata_with_rcvbl = {
            disputes: [
              {
                composite_debt_id: '71166',
                deduction_code: '71',
                original_ar: 166.67,
                current_ar: 120.4,
                benefit_type: 'CH33',
                dispute_reason: 'Test',
                rcvbl_id: 'optional_value'
              }
            ]
          }.to_json

          result = described_class::DisputeDebtValidator.parse_and_validate_metadata(
            metadata_with_rcvbl,
            user: user
          )
          expect(result[:disputes].first[:rcvbl_id]).to eq('optional_value')
        end
      end

      context 'with custom max_size' do
        it 'respects custom max_size parameter' do
          large_metadata = { disputes: [{ composite_debt_id: 'x' * 50.kilobytes }] }.to_json
          expect do
            described_class::DisputeDebtValidator.parse_and_validate_metadata(
              large_metadata,
              user: user,
              max_size: 10.kilobytes
            )
          end.to raise_error(ArgumentError, described_class::BaseValidator::INVALID_REQUEST_PAYLOAD)
        end
      end
    end
  end
end
