# frozen_string_literal: true

require 'rails_helper'
require 'dgi/submission/service'
RSpec.describe MebApi::DGI::Submission::Service do
  VCR.configure do |config|
    config.filter_sensitive_data('removed') do |interaction|
      if interaction.request.headers['Authorization']
        token = interaction.request.headers['Authorization'].first
        if (match = token.match(/^Bearer.+/) || token.match(/^token.+/))
          match[0]
        end
      end
    end
  end
  let(:user) { create(:user, :loa3) }
  let(:claimant_params) do
    {
      form_id: 1,
      education_benefit: {
        '@type': 'Chapter33',
        claimant: {
          first_name: 'Herbert',
          middle_name: 'Hoover',
          last_name: 'Hoover',
          date_of_birth: '1980-03-11',
          contact_info: {
            address_line_1: '503 upper park',
            address_line_2: '',
            city: 'falls church',
            zipcode: '22046',
            email_address: 'hhover@test.com',
            address_type: 'DOMESTIC',
            mobile_phone_number: '4409938894',
            country_code: 'US',
            state_code: 'VA'
          },
          notification_method: 'EMAIL'
        }
      },
      relinquished_benefit: {
        eff_relinquish_date: '2021-10-15',
        relinquished_benefit: 'Chapter30'
      },
      additional_considerations: {
        active_duty_kicker: 'N/A',
        academy_rotc_scholarship: 'YES',
        reserve_kicker: 'N/A',
        senior_rotc_scholarship: 'YES',
        active_duty_dod_repay_loan: 'YES'
      },
      comments: {
        disagree_with_service_period: false
      },
      direct_deposit: {
        account_number: '*********1234',
        account_type: 'Checking',
        routing_number: '*****2115'
      }
    }
  end
  let(:dd_params) do
    {
      dposit_acnt_nbr: '9876543211234',
      dposit_acnt_type_nm: 'Checking',
      financial_institution_name: 'Comerica',
      routng_trnsit_nbr: '042102115'
    }
  end

  let(:dd_params_lighthouse) do
    {
      'payment_account' => {
        'account_type' => 'CHECKING',
        'account_number' => '1234567890',
        'financial_institution_routing_number' => '031000503',
        'financial_institution_name' => 'WELLSFARGO BANK'
      },
      'controlInformation' => {
        'canUpdateDirectDeposit' => 'true',
        'isCorpAvailable' => 'true',
        'isCorpRecFound' => 'true',
        'hasNoBdnPayments' => 'true',
        'hasIndentity' => 'true',
        'hasIndex' => 'true',
        'isCompetent' => 'true',
        'hasMailingAddress' => 'true',
        'hasNoFiduciaryAssigned' => 'true',
        'isNotDeceased' => 'true',
        'hasPaymentAddress' => 'true',
        'isEduClaimAvailable' => 'true'
      }
    }
  end

  let(:claimant_params_with_asterisks) do
    duplicated_params = claimant_params.deep_dup
    # Explicitly creating the nested structure if it doesn't exist
    duplicated_params[:education_benefit] ||= {}
    duplicated_params[:education_benefit][:direct_deposit] ||= {}
    # Now that we're sure the structure exists, assign the values
    duplicated_params[:education_benefit][:direct_deposit][:account_number] = '******1234'
    duplicated_params[:education_benefit][:direct_deposit][:routing_number] = '*****2115'
    duplicated_params
  end
  let(:service) { MebApi::DGI::Submission::Service.new(user) }
  let(:faraday_response) { double('faraday_connection') }

  before do
    allow(faraday_response).to receive(:env)
  end

  describe '#submit_claim' do
    context 'Lighthouse direct deposit' do
      it 'returns a status of 200' do
        VCR.use_cassette('dgi/submit_claim_lighthouse') do
          lighthouse_dd_response = OpenStruct.new(body: dd_params_lighthouse)
          response = service.submit_claim(
            ActionController::Parameters.new(claimant_params_with_asterisks[:education_benefit]),
            Lighthouse::DirectDeposit::PaymentInfoParser.parse(lighthouse_dd_response)
          )

          expect(response.status).to eq(200)
        end
      end
    end
  end

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
          direct_deposit: {
            direct_deposit_account_number: '*********1234',
            direct_deposit_routing_number: '*****0503'
          }
        )
      end

      it 'replaces masked values with unmasked values from dd_params' do
        result = service.send(:update_dd_params, params_with_masked_values, payment_account_data)

        expect(result[:direct_deposit][:direct_deposit_account_number]).to eq('1234567890')
        expect(result[:direct_deposit][:direct_deposit_routing_number]).to eq('031000503')
      end

      context 'when dd_params is nil (service error)' do
        it 'sets direct deposit fields to nil to avoid submitting masked values' do
          result = service.send(:update_dd_params, params_with_masked_values, nil)

          expect(result[:direct_deposit][:direct_deposit_account_number]).to be_nil
          expect(result[:direct_deposit][:direct_deposit_routing_number]).to be_nil
        end
      end

      context 'when dd_params does not have payment_account' do
        let(:dd_params_without_payment_account) { OpenStruct.new(payment_account: nil) }

        it 'sets direct deposit fields to nil to avoid submitting masked values' do
          result = service.send(:update_dd_params, params_with_masked_values, dd_params_without_payment_account)

          expect(result[:direct_deposit][:direct_deposit_account_number]).to be_nil
          expect(result[:direct_deposit][:direct_deposit_routing_number]).to be_nil
        end
      end
    end

    context 'when account number does not contain asterisks (not masked)' do
      let(:params_without_masked_values) do
        ActionController::Parameters.new(
          direct_deposit: {
            direct_deposit_account_number: '9876543210',
            direct_deposit_routing_number: '021000021'
          }
        )
      end

      it 'does not replace the values regardless of dd_params' do
        result_with_data = service.send(:update_dd_params, params_without_masked_values, payment_account_data)
        result_with_nil = service.send(:update_dd_params, params_without_masked_values, nil)

        expect(result_with_data[:direct_deposit][:direct_deposit_account_number]).to eq('9876543210')
        expect(result_with_data[:direct_deposit][:direct_deposit_routing_number]).to eq('021000021')
        expect(result_with_nil[:direct_deposit][:direct_deposit_account_number]).to eq('9876543210')
        expect(result_with_nil[:direct_deposit][:direct_deposit_routing_number]).to eq('021000021')
      end
    end

    context 'when direct_deposit fields are not present' do
      let(:params_without_dd) do
        ActionController::Parameters.new(
          claimant: {
            first_name: 'John'
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
          direct_deposit: {
            direct_deposit_account_number: nil,
            direct_deposit_routing_number: nil
          }
        )
      end

      it 'does not raise an error and returns params unchanged' do
        expect do
          result = service.send(:update_dd_params, params_with_nil_account, payment_account_data)
          expect(result[:direct_deposit][:direct_deposit_account_number]).to be_nil
        end.not_to raise_error
      end
    end
  end
end
