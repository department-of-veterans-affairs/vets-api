# frozen_string_literal: true

require 'rails_helper'
require 'dgi/forms/service/submission_service'

RSpec.describe MebApi::DGI::Forms::Submission::Service do
  let(:user) { build(:user, :loa3) }
  let(:service) { described_class.new(user) }

  describe '#update_dd_params (private method)' do
    let(:payment_account_data) do
      OpenStruct.new(
        payment_account: {
          account_number: '1234567890',
          routing_number: '031000503'
        }
      )
    end

    context 'when account number contains asterisks (masked)' do
      let(:params_with_masked_values) do
        ActionController::Parameters.new(
          form: {
            direct_deposit: {
              direct_deposit_account_number: '*********1234',
              direct_deposit_routing_number: '*****0503'
            }
          }
        )
      end

      it 'replaces masked values with unmasked values from dd_params' do
        result = service.send(:update_dd_params, params_with_masked_values, payment_account_data)

        expect(result[:form][:direct_deposit][:direct_deposit_account_number]).to eq('1234567890')
        expect(result[:form][:direct_deposit][:direct_deposit_routing_number]).to eq('031000503')
      end

      context 'when dd_params is nil (service error)' do
        it 'sets direct deposit fields to nil to avoid submitting masked values' do
          result = service.send(:update_dd_params, params_with_masked_values, nil)

          expect(result[:form][:direct_deposit][:direct_deposit_account_number]).to be_nil
          expect(result[:form][:direct_deposit][:direct_deposit_routing_number]).to be_nil
        end
      end

      context 'when dd_params does not have payment_account' do
        let(:dd_params_without_payment_account) { OpenStruct.new(payment_account: nil) }

        it 'sets direct deposit fields to nil to avoid submitting masked values' do
          result = service.send(:update_dd_params, params_with_masked_values, dd_params_without_payment_account)

          expect(result[:form][:direct_deposit][:direct_deposit_account_number]).to be_nil
          expect(result[:form][:direct_deposit][:direct_deposit_routing_number]).to be_nil
        end
      end
    end

    context 'when account number does not contain asterisks (not masked)' do
      let(:params_without_masked_values) do
        ActionController::Parameters.new(
          form: {
            direct_deposit: {
              direct_deposit_account_number: '9876543210',
              direct_deposit_routing_number: '021000021'
            }
          }
        )
      end

      it 'does not replace the values regardless of dd_params' do
        result_with_data = service.send(:update_dd_params, params_without_masked_values, payment_account_data)
        result_with_nil = service.send(:update_dd_params, params_without_masked_values, nil)

        expect(result_with_data[:form][:direct_deposit][:direct_deposit_account_number]).to eq('9876543210')
        expect(result_with_data[:form][:direct_deposit][:direct_deposit_routing_number]).to eq('021000021')
        expect(result_with_nil[:form][:direct_deposit][:direct_deposit_account_number]).to eq('9876543210')
        expect(result_with_nil[:form][:direct_deposit][:direct_deposit_routing_number]).to eq('021000021')
      end
    end

    context 'when direct_deposit fields are not present' do
      let(:params_without_dd) do
        ActionController::Parameters.new(
          form: {
            claimant: {
              first_name: 'John'
            }
          }
        )
      end

      it 'returns params unchanged' do
        result = service.send(:update_dd_params, params_without_dd, payment_account_data)

        expect(result).to eq(params_without_dd)
      end
    end

    context 'when account number is nil' do
      let(:params_with_nil_account) do
        ActionController::Parameters.new(
          form: {
            direct_deposit: {
              direct_deposit_account_number: nil,
              direct_deposit_routing_number: nil
            }
          }
        )
      end

      it 'does not raise an error and returns params unchanged' do
        expect do
          result = service.send(:update_dd_params, params_with_nil_account, payment_account_data)
          expect(result[:form][:direct_deposit][:direct_deposit_account_number]).to be_nil
        end.not_to raise_error
      end
    end
  end
end
