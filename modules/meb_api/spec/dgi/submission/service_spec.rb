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
end
