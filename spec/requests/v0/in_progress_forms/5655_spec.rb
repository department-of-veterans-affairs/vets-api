# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::InProgressForms::5655' do
  let(:user_loa3) { build(:user, :loa3) }
  let(:vcr_options) { { match_requests_on: %i[path query] } }

  def with_vcr(&block)
    VCR.use_cassette('evss/pciu/email', vcr_options) do
      VCR.use_cassette('evss/pciu/primary_phone', vcr_options) do
        VCR.use_cassette('bgs/people_service/person_data', vcr_options) do
          block.call
        end
      end
    end
  end

  describe '/v0/in_progress_forms/5655' do
    let(:endpoint) { '/v0/in_progress_forms/5655' }
    let(:comp_and_pen_payments) do
      [
        { payment_date: DateTime.now - 2.months, payment_amount: '1500' },
        { payment_date: DateTime.now - 10.days, payment_amount: '3000' }
      ]
    end

    before do
      sign_in_as(user_loa3)
      allow_any_instance_of(DebtManagementCenter::PaymentsService).to(
        receive(:compensation_and_pension).and_return(comp_and_pen_payments)
      )
      allow_any_instance_of(DebtManagementCenter::PaymentsService).to(
        receive(:education).and_return(nil)
      )
    end

    context 'with payments' do
      let(:expected_payments) { [{ 'veteranOrSpouse' => 'VETERAN', 'compensationAndPension' => '3000' }] }

      it 'returns a pre-filled form' do
        with_vcr do
          get endpoint
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['formData']['income']).to eq(expected_payments)
        end
      end
    end
  end
end
