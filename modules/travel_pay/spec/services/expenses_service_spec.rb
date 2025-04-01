# frozen_string_literal: true

require 'rails_helper'
require 'securerandom'

describe TravelPay::ExpensesService do
  context 'add_expense' do
    let(:user) { build(:user) }
    let(:add_expense_data) do
      {
        'data' =>
        {
          'expenseId' => '3fa85f64-5717-4562-b3fc-2c963f66afa6'
        }
      }
    end
    let(:add_expense_response) do
      Faraday::Response.new(
        body: add_expense_data
      )
    end

    let(:tokens) { { veis_token: 'veis_token', btsss_token: 'btsss_token' } }

    context 'add new expense' do
      before do
        auth_manager = object_double(TravelPay::AuthManager.new(123, user), authorize: tokens)
        @service = TravelPay::ExpensesService.new(auth_manager)
      end

      it 'returns an expense ID when passed a valid claim id and appointment date' do
        params = { 'claim_id' => '73611905-71bf-46ed-b1ec-e790593b8565',
                   'appt_date' => '2024-10-02T14:36:38.043Z',
                   'trip_type' => 'RoundTrip',
                   'description' => 'this is my description' }

        allow_any_instance_of(TravelPay::ExpensesClient)
          .to receive(:add_mileage_expense)
          .with(tokens[:veis_token], tokens[:btsss_token], params)
          .and_return(add_expense_response)

        actual_new_expense_response = @service.add_expense(params)

        expect(actual_new_expense_response['data']).to equal(add_expense_data['data'])
      end

      it 'succeeds and returns an expense ID when trip type is not specified' do
        params = { 'claim_id' => '73611905-71bf-46ed-b1ec-e790593b8565',
                   'appt_date' => '2024-10-02T14:36:38.043Z' }

        allow_any_instance_of(TravelPay::ExpensesClient)
          .to receive(:add_mileage_expense)
          .with(tokens[:veis_token], tokens[:btsss_token], params)
          .and_return(add_expense_response)

        actual_new_expense_response = @service.add_expense(params)

        expect(actual_new_expense_response['data']).to equal(add_expense_data['data'])
      end

      it 'throws an ArgumentException if not passed the right params' do
        expect do
          @service.add_expense({ 'claim_id' => nil,
                                 'appt_date' => '2024-10-02T14:36:38.043Z',
                                 'trip_type' => 'OneWay' })
        end.to raise_error(ArgumentError, /You must provide/i)
      end
    end
  end
end
