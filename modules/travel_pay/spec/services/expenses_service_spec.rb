# frozen_string_literal: true

require 'rails_helper'
require 'securerandom'

describe TravelPay::ExpensesService do
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

  describe 'create_expense' do
    before do
      auth_manager = object_double(TravelPay::AuthManager.new(123, user), authorize: tokens)
      @expenses_client = instance_double(TravelPay::ExpensesClient)
      @service = TravelPay::ExpensesService.new(auth_manager)
      # By default, feature flag is disabled (includes receipt)
      allow(Flipper).to receive(:enabled?).with(:travel_pay_exclude_expense_placeholder_receipt).and_return(false)
    end

    context 'with non-mileage expense types' do
      let(:general_expense_response) do
        Faraday::Response.new(
          body: { 'data' => { 'id' => 'expense-456' } }
        )
      end

      it 'routes to generic client method for other expense types' do
        params = {
          'claim_id' => '73611905-71bf-46ed-b1ec-e790593b8565',
          'expense_type' => 'lodging',
          'purchase_date' => '2024-10-02',
          'description' => 'Hotel stay',
          'cost_requested' => 125.50
        }

        expected_request_body = {
          'claimId' => '73611905-71bf-46ed-b1ec-e790593b8565',
          'dateIncurred' => '2024-10-02',
          'description' => 'Hotel stay',
          'costRequested' => 125.50,
          'expenseType' => 'lodging',
          'expenseReceipt' => {
            'contentType' => 'text/plain',
            'length' => 11,
            'fileName' => 'placeholder.txt',
            'fileData' => 'cGxhY2Vob2xkZXI='
          }
        }

        allow_any_instance_of(TravelPay::ExpensesClient)
          .to receive(:add_expense)
          .with(tokens[:veis_token], tokens[:btsss_token], 'lodging', expected_request_body)
          .and_return(general_expense_response)

        result = @service.create_expense(params)
        expect(result).to eq({ 'id' => 'expense-456' })
      end

      it 'handles meal expenses' do
        params = {
          'claim_id' => '73611905-71bf-46ed-b1ec-e790593b8565',
          'expense_type' => 'meal',
          'purchase_date' => '2024-10-02',
          'description' => 'Lunch during appointment',
          'cost_requested' => 15.75
        }

        expected_request_body = {
          'claimId' => '73611905-71bf-46ed-b1ec-e790593b8565',
          'dateIncurred' => '2024-10-02',
          'description' => 'Lunch during appointment',
          'costRequested' => 15.75,
          'expenseType' => 'meal',
          'expenseReceipt' => {
            'contentType' => 'text/plain',
            'length' => 11,
            'fileName' => 'placeholder.txt',
            'fileData' => 'cGxhY2Vob2xkZXI='
          }
        }

        allow_any_instance_of(TravelPay::ExpensesClient)
          .to receive(:add_expense)
          .with(tokens[:veis_token], tokens[:btsss_token], 'meal', expected_request_body)
          .and_return(general_expense_response)

        result = @service.create_expense(params)
        expect(result).to eq({ 'id' => 'expense-456' })
      end

      it 'handles other expense types' do
        params = {
          'claim_id' => '73611905-71bf-46ed-b1ec-e790593b8565',
          'expense_type' => 'other',
          'purchase_date' => '2024-10-02',
          'description' => 'Parking fee',
          'cost_requested' => 10.00
        }

        expected_request_body = {
          'claimId' => '73611905-71bf-46ed-b1ec-e790593b8565',
          'dateIncurred' => '2024-10-02',
          'description' => 'Parking fee',
          'costRequested' => 10.00,
          'expenseType' => 'other',
          'expenseReceipt' => {
            'contentType' => 'text/plain',
            'length' => 11,
            'fileName' => 'placeholder.txt',
            'fileData' => 'cGxhY2Vob2xkZXI='
          }
        }

        allow_any_instance_of(TravelPay::ExpensesClient)
          .to receive(:add_expense)
          .with(tokens[:veis_token], tokens[:btsss_token], 'other', expected_request_body)
          .and_return(general_expense_response)

        result = @service.create_expense(params)
        expect(result).to eq({ 'id' => 'expense-456' })
      end

      it 'handles API errors gracefully' do
        params = {
          'claim_id' => '73611905-71bf-46ed-b1ec-e790593b8565',
          'expense_type' => 'lodging',
          'purchase_date' => '2024-10-02',
          'description' => 'Hotel stay',
          'cost_requested' => 125.50
        }

        faraday_error = Faraday::BadRequestError.new('Bad request')
        allow_any_instance_of(TravelPay::ExpensesClient)
          .to receive(:add_expense)
          .and_raise(faraday_error)

        # Mock the ServiceError.raise_mapped_error method to raise a Common::Exceptions error
        allow(TravelPay::ServiceError).to receive(:raise_mapped_error).with(faraday_error)
                                                                      .and_raise(
                                                                        Common::Exceptions::BadRequest.new(
                                                                          errors: [{ title: 'API Error', status: 400 }]
                                                                        )
                                                                      )

        expect { @service.create_expense(params) }.to raise_error(Common::Exceptions::BadRequest)
      end

      context 'with feature flag travel_pay_exclude_expense_placeholder_receipt' do
        it 'excludes placeholder receipt when feature flag is enabled' do
          allow(Flipper).to receive(:enabled?).with(:travel_pay_exclude_expense_placeholder_receipt).and_return(true)

          params = {
            'claim_id' => '73611905-71bf-46ed-b1ec-e790593b8565',
            'expense_type' => 'other',
            'purchase_date' => '2024-10-02',
            'description' => 'Parking fee',
            'cost_requested' => 10.00
          }

          expected_request_body_without_receipt = {
            'claimId' => '73611905-71bf-46ed-b1ec-e790593b8565',
            'dateIncurred' => '2024-10-02',
            'description' => 'Parking fee',
            'costRequested' => 10.00,
            'expenseType' => 'other'
          }

          allow_any_instance_of(TravelPay::ExpensesClient)
            .to receive(:add_expense)
            .with(tokens[:veis_token], tokens[:btsss_token], 'other', expected_request_body_without_receipt)
            .and_return(general_expense_response)

          result = @service.create_expense(params)
          expect(result).to eq({ 'id' => 'expense-456' })
        end

        it 'includes placeholder receipt when feature flag is disabled (default)' do
          allow(Flipper).to receive(:enabled?).with(:travel_pay_exclude_expense_placeholder_receipt).and_return(false)

          params = {
            'claim_id' => '73611905-71bf-46ed-b1ec-e790593b8565',
            'expense_type' => 'other',
            'purchase_date' => '2024-10-02',
            'description' => 'Parking fee',
            'cost_requested' => 10.00
          }

          expected_request_body_with_receipt = {
            'claimId' => '73611905-71bf-46ed-b1ec-e790593b8565',
            'dateIncurred' => '2024-10-02',
            'description' => 'Parking fee',
            'costRequested' => 10.00,
            'expenseType' => 'other',
            'expenseReceipt' => {
              'contentType' => 'text/plain',
              'length' => 11,
              'fileName' => 'placeholder.txt',
              'fileData' => 'cGxhY2Vob2xkZXI='
            }
          }

          allow_any_instance_of(TravelPay::ExpensesClient)
            .to receive(:add_expense)
            .with(tokens[:veis_token], tokens[:btsss_token], 'other', expected_request_body_with_receipt)
            .and_return(general_expense_response)

          result = @service.create_expense(params)
          expect(result).to eq({ 'id' => 'expense-456' })
        end
      end
    end

    it 'raises ArgumentError when claim_id is missing' do
      params = {
        'expense_type' => 'lodging',
        'purchase_date' => '2024-10-02',
        'description' => 'Hotel stay',
        'cost_requested' => 125.50
      }

      expect do
        @service.create_expense(params)
      end.to raise_error(ArgumentError, 'You must provide a claim ID to create an expense.')
    end
  end

  describe 'add_mileage_expense method' do
    let(:auth_manager) { object_double(TravelPay::AuthManager.new(123, user), authorize: tokens) }
    let(:service) { TravelPay::ExpensesService.new(auth_manager) }

    it 'returns an expense ID when passed a valid claim id and appointment date' do
      params = { 'claim_id' => '73611905-71bf-46ed-b1ec-e790593b8565',
                 'appt_date' => '2024-10-02T14:36:38.043Z',
                 'trip_type' => 'RoundTrip',
                 'description' => 'this is my description' }

      allow_any_instance_of(TravelPay::ExpensesClient)
        .to receive(:add_mileage_expense)
        .with(tokens[:veis_token], tokens[:btsss_token], params)
        .and_return(add_expense_response)

      actual_new_expense_response = service.add_expense(params)

      expect(actual_new_expense_response).to equal(add_expense_data['data'])
    end

    it 'succeeds and returns an expense ID when trip type is not specified' do
      params = { 'claim_id' => '73611905-71bf-46ed-b1ec-e790593b8565',
                 'appt_date' => '2024-10-02T14:36:38.043Z' }

      allow_any_instance_of(TravelPay::ExpensesClient)
        .to receive(:add_mileage_expense)
        .with(tokens[:veis_token], tokens[:btsss_token], params)
        .and_return(add_expense_response)

      actual_new_expense_response = service.add_expense(params)

      expect(actual_new_expense_response).to equal(add_expense_data['data'])
    end

    it 'throws an ArgumentException if not passed the right params' do
      expect do
        service.add_expense({ 'claim_id' => nil,
                              'appt_date' => '2024-10-02T14:36:38.043Z',
                              'trip_type' => 'OneWay' })
      end.to raise_error(ArgumentError, /You must provide/i)
    end
  end

  describe '#delete_expense' do
    let(:auth_manager) { instance_double(TravelPay::AuthManager, authorize: { veis_token: 'veis_token', btsss_token: 'btsss_token' }) }
    let(:service) { described_class.new(auth_manager) }
    let(:client_double) { instance_double(TravelPay::ExpensesClient) }
    let(:expense_id) { '123e4567-e89b-12d3-a456-426614174000' }
    let(:expense_type) { 'other' }
    let(:delete_response) { double(body: { 'data' => { 'id' => expense_id } }) }

    before do
      allow(TravelPay::ExpensesClient).to receive(:new).and_return(client_double)
      allow(client_double).to receive(:delete_expense).and_return(delete_response)
    end

    it 'calls the client with correct arguments' do
      result = service.delete_expense(expense_id:, expense_type:)

      expect(client_double).to have_received(:delete_expense)
        .with('veis_token', 'btsss_token', expense_id, expense_type)
      expect(result).to eq({ 'id' => expense_id })
    end

    it 'raises ArgumentError if expense_id is missing' do
      expect { service.delete_expense(expense_id: nil, expense_type:) }
        .to raise_error(ArgumentError, /You must provide an expense ID/)
    end

    it 'raises ArgumentError if expense_type is missing' do
      expect { service.delete_expense(expense_id:, expense_type: nil) }
        .to raise_error(ArgumentError, /You must provide an expense type/)
    end
  end
end
