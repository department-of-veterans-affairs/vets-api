# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'raises invalid payload error' do |invalid_inputs, validator, method_name, method_args_key = nil|
  it 'raises ArgumentError with invalid payload message' do
    invalid_inputs.each do |invalid_input|
      if invalid_input.is_a?(Array) && invalid_input.length == 2 && invalid_input[1].is_a?(Hash)
        # Handle validate_field_schema case: [records, { keyword_args }]
        expect { validator.send(method_name, invalid_input[0], **invalid_input[1]) }
          .to raise_error(ArgumentError, 'Invalid request payload')
      elsif method_args_key.nil?
        # Handle single argument case
        expect { validator.send(method_name, invalid_input) }
          .to raise_error(ArgumentError, 'Invalid request payload')
      else
        # Handle case with keyword args (method_args_key is a symbol indicating which let variable to use)
        args = method_args_key == :user ? { user: } : {}
        expect { validator.send(method_name, invalid_input, **args) }
          .to raise_error(ArgumentError, 'Invalid request payload')
      end
    end
  end
end

RSpec.describe DebtsApi::Concerns::SubmissionValidation do
  let(:base_validator) { described_class::BaseValidator }
  let(:dispute_validator) { described_class::DisputeDebtValidator }
  let(:invalid_payload_message) { 'Invalid request payload' }

  describe 'BaseValidator' do
    describe '.parse_json_safely' do
      it 'parses valid JSON and symbolizes keys' do
        result = base_validator.parse_json_safely('{"composite_debt_id": "123"}')
        expect(result).to eq({ composite_debt_id: '123' })
      end

      it_behaves_like 'raises invalid payload error',
                      [nil, '{invalid}', "{\"key\": \"#{'x' * 101.kilobytes}\"}"],
                      described_class::BaseValidator,
                      :parse_json_safely

      it 'respects custom max_size parameter' do
        expect { base_validator.parse_json_safely("{\"key\": \"#{'x' * 50.kilobytes}\"}", max_size: 10.kilobytes) }
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
                                                              string_fields: %i[composite_debt_id dispute_reason])
        end.not_to raise_error
      end

      it_behaves_like 'raises invalid payload error',
                      [
                        [{ not: 'array' }, { field_name: 'disputes', required_fields: [] }],
                        [['not hash'], { field_name: 'disputes', required_fields: [] }],
                        [[{ id: '123' }], { field_name: 'disputes', required_fields: [:composite_debt_id] }],
                        [[{ composite_debt_id: 'x' * 1001 }],
                         { field_name: 'disputes', required_fields: [:composite_debt_id],
                           string_fields: [:composite_debt_id] }],
                        [[{ composite_debt_id: '123', reason: "test\x00null" }],
                         { field_name: 'disputes', required_fields: [:composite_debt_id], string_fields: [:reason] }]
                      ],
                      described_class::BaseValidator,
                      :validate_field_schema
    end
  end

  describe 'DisputeDebtValidator' do
    let(:user) { build(:user, :loa3) }
    let(:valid_metadata) do
      { disputes: [{ composite_debt_id: '71166', deduction_code: '71', original_ar: 166.67, current_ar: 120.4,
                     benefit_type: 'CH33', dispute_reason: 'Test' }] }.to_json
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
          result = dispute_validator.parse_and_validate_metadata(valid_metadata, user:)
          expect(result[:disputes].first[:composite_debt_id]).to eq('71166')
        end.not_to raise_error
        expect(mock_service).to have_received(:get_debts_by_ids).with(['71166'])
      end

      it_behaves_like 'raises invalid payload error',
                      ['{invalid}', '["not", "object"]', { other: 'key' }.to_json,
                       { disputes: { not: 'array' } }.to_json, { disputes: ['not hash'] }.to_json],
                      described_class::DisputeDebtValidator,
                      :parse_and_validate_metadata,
                      :user

      it_behaves_like 'raises invalid payload error',
                      [
                        { disputes: [{ composite_debt_id: '123' }] }.to_json,
                        { disputes: [{ deduction_code: '71', original_ar: 1, current_ar: 1, benefit_type: 'CH33',
                                       dispute_reason: 'Test' }] }.to_json
                      ],
                      described_class::DisputeDebtValidator,
                      :parse_and_validate_metadata,
                      :user

      it 'raises ArgumentError when debts do not exist for user' do
        allow(mock_service).to receive(:get_debts_by_ids).and_return([])
        expect { dispute_validator.parse_and_validate_metadata(valid_metadata, user:) }
          .to raise_error(ArgumentError, invalid_payload_message)
      end

      it 'handles optional numeric rcvbl_id and custom max_size' do
        metadata = { disputes: [{ composite_debt_id: '71166', deduction_code: '71', original_ar: 1, current_ar: 1,
                                  benefit_type: 'CH33', dispute_reason: 'Test', rcvbl_id: 908_776_456 }] }.to_json
        result = dispute_validator.parse_and_validate_metadata(metadata, user:)
        expect(result[:disputes].first[:rcvbl_id]).to eq(908_776_456)

        large = { disputes: [{ composite_debt_id: 'x' * 50.kilobytes }] }.to_json
        expect { dispute_validator.parse_and_validate_metadata(large, user:, max_size: 10.kilobytes) }
          .to raise_error(ArgumentError, invalid_payload_message)
      end

      it 'raises ArgumentError when rcvbl_id is a string' do
        metadata = { disputes: [{ composite_debt_id: '71166', deduction_code: '71', original_ar: 1, current_ar: 1,
                                  benefit_type: 'CH33', dispute_reason: 'Test', rcvbl_id: '908776456' }] }.to_json
        expect { dispute_validator.parse_and_validate_metadata(metadata, user:) }
          .to raise_error(ArgumentError, invalid_payload_message)
      end
    end
  end
end
