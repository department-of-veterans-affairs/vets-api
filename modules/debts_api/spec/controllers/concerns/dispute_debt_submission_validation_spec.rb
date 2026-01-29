# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DebtsApi::Concerns::DisputeDebtSubmissionValidation do
  let(:base_validator) { described_class::BaseValidator }
  let(:dispute_validator) { described_class::DisputeDebtValidator }

  describe 'BaseValidator' do
    describe '.parse_json_safely' do
      it 'parses valid JSON and symbolizes keys' do
        result = base_validator.parse_json_safely('{"composite_debt_id": "123"}')
        expect(result).to eq({ composite_debt_id: '123' })
      end

      it 'raises ArgumentError for nil, invalid JSON, or oversized JSON' do
        expect { base_validator.parse_json_safely(nil) }
          .to raise_error(ArgumentError, base_validator::INVALID_REQUEST_PAYLOAD)
        expect { base_validator.parse_json_safely('{invalid}') }
          .to raise_error(ArgumentError, base_validator::INVALID_REQUEST_PAYLOAD)
        expect { base_validator.parse_json_safely('{"key": "' + ('x' * 101.kilobytes) + '"}') }
          .to raise_error(ArgumentError, base_validator::INVALID_REQUEST_PAYLOAD)
      end

      it 'respects custom max_size parameter' do
        expect { base_validator.parse_json_safely('{"key": "' + ('x' * 50.kilobytes) + '"}', max_size: 10.kilobytes) }
          .to raise_error(ArgumentError)
      end
    end

    describe '.validate_field_schema' do
      let(:valid_records) do
        [
          { composite_debt_id: '123', deduction_code: '71', dispute_reason: 'Test' },
          { composite_debt_id: '456', deduction_code: '72', dispute_reason: 'Another' }
        ]
      end

      it 'validates valid records successfully' do
        expect do
          base_validator.validate_field_schema(valid_records, field_name: 'disputes',
                                                             required_fields: [:composite_debt_id],
                                                             string_fields: [:composite_debt_id, :dispute_reason])
        end.not_to raise_error
      end

      it 'raises ArgumentError for invalid structure or content' do
        expect { base_validator.validate_field_schema({ not: 'array' }, field_name: 'disputes', required_fields: []) }
          .to raise_error(ArgumentError, base_validator::INVALID_REQUEST_PAYLOAD)
        expect { base_validator.validate_field_schema(['not hash'], field_name: 'disputes', required_fields: []) }
          .to raise_error(ArgumentError, base_validator::INVALID_REQUEST_PAYLOAD)
        expect { base_validator.validate_field_schema([{ id: '123' }], field_name: 'disputes', required_fields: [:composite_debt_id]) }
          .to raise_error(ArgumentError, base_validator::INVALID_REQUEST_PAYLOAD)
        expect { base_validator.validate_field_schema([{ composite_debt_id: 'x' * 1001 }], field_name: 'disputes', required_fields: [:composite_debt_id], string_fields: [:composite_debt_id]) }
          .to raise_error(ArgumentError, base_validator::INVALID_REQUEST_PAYLOAD)
        expect { base_validator.validate_field_schema([{ composite_debt_id: '123', reason: "test\x00null" }], field_name: 'disputes', required_fields: [:composite_debt_id], string_fields: [:reason]) }
          .to raise_error(ArgumentError, base_validator::INVALID_REQUEST_PAYLOAD)
      end
    end
  end

  describe 'DisputeDebtValidator' do
    let(:user) { build(:user, :loa3) }
    let(:valid_metadata) do
      { disputes: [{ composite_debt_id: '71166', deduction_code: '71', original_ar: 166.67, current_ar: 120.4, benefit_type: 'CH33', dispute_reason: 'Test' }] }.to_json
    end
    let(:mock_service) { instance_double(DebtManagementCenter::DebtsService) }
    let(:mock_debt) { { 'compositeDebtId' => '71166' } }

    before do
      allow(DebtManagementCenter::DebtsService).to receive(:new).with(user).and_return(mock_service)
      allow(mock_service).to receive(:get_debts_by_ids).and_return([mock_debt])
    end

    describe '.parse_and_validate_metadata' do
      it 'validates and returns parsed metadata without raising errors' do
        expect do
          result = dispute_validator.parse_and_validate_metadata(valid_metadata, user: user)
          expect(result[:disputes].first[:composite_debt_id]).to eq('71166')
        end.not_to raise_error
        expect(mock_service).to have_received(:get_debts_by_ids).with(['71166'])
      end

      it 'raises ArgumentError for invalid JSON structure' do
        expect { dispute_validator.parse_and_validate_metadata('{invalid}', user: user) }
          .to raise_error(ArgumentError, base_validator::INVALID_REQUEST_PAYLOAD)
        expect { dispute_validator.parse_and_validate_metadata('["not", "object"]', user: user) }
          .to raise_error(ArgumentError, 'metadata must be a JSON object')
        expect { dispute_validator.parse_and_validate_metadata({ other: 'key' }.to_json, user: user) }
          .to raise_error(ArgumentError, 'metadata must include a "disputes" key')
        expect { dispute_validator.parse_and_validate_metadata({ disputes: { not: 'array' } }.to_json, user: user) }
          .to raise_error(ArgumentError, base_validator::INVALID_REQUEST_PAYLOAD)
        expect { dispute_validator.parse_and_validate_metadata({ disputes: ['not hash'] }.to_json, user: user) }
          .to raise_error(ArgumentError, 'disputes[0] must be an object')
      end

      it 'raises ArgumentError for missing required fields or composite_debt_ids' do
        expect { dispute_validator.parse_and_validate_metadata({ disputes: [{ composite_debt_id: '123' }] }.to_json, user: user) }
          .to raise_error(ArgumentError, base_validator::INVALID_REQUEST_PAYLOAD)
        expect { dispute_validator.parse_and_validate_metadata({ disputes: [{ deduction_code: '71', original_ar: 1, current_ar: 1, benefit_type: 'CH33', dispute_reason: 'Test' }] }.to_json, user: user) }
          .to raise_error(ArgumentError, 'At least one composite_debt_id is required in disputes')
      end

      it 'raises ArgumentError when debts do not exist for user' do
        allow(mock_service).to receive(:get_debts_by_ids).and_return([])
        expect { dispute_validator.parse_and_validate_metadata(valid_metadata, user: user) }
          .to raise_error(ArgumentError, /Invalid debt identifiers/)
      end

      it 'handles optional rcvbl_id and custom max_size' do
        metadata = { disputes: [{ composite_debt_id: '71166', deduction_code: '71', original_ar: 1, current_ar: 1, benefit_type: 'CH33', dispute_reason: 'Test', rcvbl_id: 'opt' }] }.to_json
        result = dispute_validator.parse_and_validate_metadata(metadata, user: user)
        expect(result[:disputes].first[:rcvbl_id]).to eq('opt')

        large = { disputes: [{ composite_debt_id: 'x' * 50.kilobytes }] }.to_json
        expect { dispute_validator.parse_and_validate_metadata(large, user: user, max_size: 10.kilobytes) }
          .to raise_error(ArgumentError, base_validator::INVALID_REQUEST_PAYLOAD)
      end
    end
  end
end
