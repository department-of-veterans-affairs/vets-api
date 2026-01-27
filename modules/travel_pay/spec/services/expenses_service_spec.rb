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
          'expenseType' => 'lodging'
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
          'expenseType' => 'meal'
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
          'expenseType' => 'other'
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
      end.to raise_error(ArgumentError, /You must provide/i)
    end
  end

  context 'get_expense method' do
    let(:auth_manager) { object_double(TravelPay::AuthManager.new(123, user), authorize: tokens) }
    let(:service) { TravelPay::ExpensesService.new(auth_manager) }
    let(:expense_id) { SecureRandom.uuid }
    let(:get_expense_data) do
      {
        'data' => {
          'id' => expense_id,
          'expenseType' => 'mileage',
          'claimId' => SecureRandom.uuid,
          'dateIncurred' => '2024-10-02T14:36:38.043Z',
          'description' => 'Mileage expense',
          'status' => 'approved'
        }
      }
    end
    let(:get_expense_response) do
      Faraday::Response.new(body: get_expense_data)
    end

    it 'returns expense details when passed valid expense type and ID' do
      allow_any_instance_of(TravelPay::ExpensesClient)
        .to receive(:get_expense)
        .with(tokens[:veis_token], tokens[:btsss_token], 'other', expense_id)
        .and_return(get_expense_response)

      result = service.get_expense('other', expense_id)

      expect(result).to eq(get_expense_data['data'])
    end

    it 'raises ArgumentError when expense_type is blank' do
      expect do
        service.get_expense('', expense_id)
      end.to raise_error(ArgumentError, 'You must provide an expense type to get an expense.')
    end

    it 'raises ArgumentError when expense_id is blank' do
      expect do
        service.get_expense('other', '')
      end.to raise_error(ArgumentError, 'You must provide an expense ID to get an expense.')
    end

    it 'handles API errors gracefully' do
      faraday_error = Faraday::ClientError.new('Expense not found')
      allow_any_instance_of(TravelPay::ExpensesClient)
        .to receive(:get_expense)
        .and_raise(faraday_error)

      # Mock the ServiceError.raise_mapped_error method to raise a Common::Exceptions error
      allow(TravelPay::ServiceError).to receive(:raise_mapped_error).with(faraday_error)
                                                                    .and_raise(
                                                                      Common::Exceptions::RecordNotFound.new(expense_id)
                                                                    )

      expect { service.get_expense('other', expense_id) }.to raise_error(Common::Exceptions::RecordNotFound)
    end

    it 'overwrites expenseType with name for parking expenses' do
      parking_expense_data = {
        'data' => {
          'id' => expense_id,
          'expenseType' => 'Other',
          'name' => 'Parking',
          'claimId' => SecureRandom.uuid,
          'dateIncurred' => '2024-10-02T14:36:38.043Z',
          'description' => 'Parking expense',
          'costRequested' => 5.00
        }
      }
      parking_expense_response = Faraday::Response.new(body: parking_expense_data)

      allow_any_instance_of(TravelPay::ExpensesClient)
        .to receive(:get_expense)
        .with(tokens[:veis_token], tokens[:btsss_token], 'other', expense_id)
        .and_return(parking_expense_response)

      result = service.get_expense('other', expense_id)

      expect(result['expenseType']).to eq('Parking')
      expect(result['name']).to eq('Parking')
    end

    it 'does not overwrite expenseType for non-parking expenses even when name is present' do
      expense_with_name_data = {
        'data' => {
          'id' => expense_id,
          'expenseType' => 'Mileage',
          'name' => 'Mileage Expense',
          'claimId' => SecureRandom.uuid,
          'dateIncurred' => '2024-10-02T14:36:38.043Z',
          'description' => 'Mileage expense'
        }
      }
      expense_with_name_response = Faraday::Response.new(body: expense_with_name_data)

      allow_any_instance_of(TravelPay::ExpensesClient)
        .to receive(:get_expense)
        .with(tokens[:veis_token], tokens[:btsss_token], 'mileage', expense_id)
        .and_return(expense_with_name_response)

      result = service.get_expense('mileage', expense_id)

      expect(result['expenseType']).to eq('Mileage')
      expect(result['name']).to eq('Mileage Expense')
    end

    it 'does not overwrite expenseType when name is blank' do
      expense_blank_name_data = {
        'data' => {
          'id' => expense_id,
          'expenseType' => 'Other',
          'name' => '',
          'claimId' => SecureRandom.uuid,
          'dateIncurred' => '2024-10-02T14:36:38.043Z',
          'description' => 'Some expense'
        }
      }
      expense_blank_name_response = Faraday::Response.new(body: expense_blank_name_data)

      allow_any_instance_of(TravelPay::ExpensesClient)
        .to receive(:get_expense)
        .with(tokens[:veis_token], tokens[:btsss_token], 'other', expense_id)
        .and_return(expense_blank_name_response)

      result = service.get_expense('other', expense_id)

      expect(result['expenseType']).to eq('Other')
    end

    it 'returns reasonNotUsingPOV for common carrier expenses with a valid explanation value' do
      explanation_value = TravelPay::Constants::COMMON_CARRIER_EXPLANATIONS.values.first

      common_carrier_expense_data = {
        'data' => {
          'id' => expense_id,
          'expenseType' => 'CommonCarrier',
          'claimId' => SecureRandom.uuid,
          'dateIncurred' => '2024-10-02T14:36:38.043Z',
          'description' => 'Taxi to appointment',
          'reasonNotUsingPOV' => explanation_value,
          'carrierType' => 'Taxi'
        }
      }

      response = Faraday::Response.new(body: common_carrier_expense_data)

      allow_any_instance_of(TravelPay::ExpensesClient)
        .to receive(:get_expense)
        .with(tokens[:veis_token], tokens[:btsss_token], 'commoncarrier', expense_id)
        .and_return(response)

      result = service.get_expense('commoncarrier', expense_id)

      expect(result['reasonNotUsingPOV']).to eq(explanation_value)
      expect(TravelPay::Constants::COMMON_CARRIER_EXPLANATIONS.values)
        .to include(result['reasonNotUsingPOV'])
      expect(result).to have_key('reasonNotUsingPOV')
      expect(result).not_to have_key('reasonNotUsingPov')
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

  describe '#update_expense' do
    let(:auth_manager) { instance_double(TravelPay::AuthManager, authorize: { veis_token: 'veis_token', btsss_token: 'btsss_token' }) }
    let(:params) do
      {
        'expense_type' => 'lodging',
        'purchase_date' => '2024-10-02',
        'description' => 'Hotel stay',
        'cost_requested' => 125.50
      }
    end
    let(:expected_request_body) do
      {
        'dateIncurred' => '2024-10-02',
        'description' => 'Hotel stay',
        'costRequested' => 125.50,
        'expenseType' => 'lodging'
      }
    end
    let(:service) { described_class.new(auth_manager) }
    let(:client_double) { instance_double(TravelPay::ExpensesClient) }
    let(:expense_id) { '123e4567-e89b-12d3-a456-426614174000' }
    let(:expense_type) { 'other' }
    let(:update_response) { double(body: { 'data' => { 'id' => expense_id } }) }

    before do
      allow(TravelPay::ExpensesClient).to receive(:new).and_return(client_double)
      allow(client_double).to receive(:update_expense).and_return(update_response)
    end

    it 'calls the client with correct arguments' do
      result = service.update_expense(expense_id, expense_type, params)

      expect(client_double).to have_received(:update_expense)
        .with('veis_token', 'btsss_token', expense_id, expense_type, expected_request_body)
      expect(result).to eq({ 'id' => expense_id })
    end

    it 'handles partial update payload' do
      partial_params = { 'description' => 'Updated hotel stay' }
      partial_request_body = {
        'description' => 'Updated hotel stay'
      }

      result = service.update_expense(expense_id, expense_type, partial_params)
      expect(client_double).to have_received(:update_expense)
        .with('veis_token', 'btsss_token', expense_id, expense_type, partial_request_body)
      expect(result).to eq({ 'id' => expense_id })
    end

    it 'raises ArgumentError if expense_id is missing' do
      expect { service.update_expense(nil, expense_type, params) }
        .to raise_error(ArgumentError, /You must provide an expense ID/)
    end

    it 'raises ArgumentError if expense_type is missing' do
      expect { service.update_expense(expense_id, nil, params) }
        .to raise_error(ArgumentError, /You must provide an expense type/)
    end

    it 'raises ArgumentError if params is missing' do
      expect { service.update_expense(expense_id, expense_type, nil) }
        .to raise_error(ArgumentError, /You must provide at least one field/)
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

  describe '#build_expense_request_body (private method)' do
    let(:auth_manager) { instance_double(TravelPay::AuthManager, authorize: { veis_token: 'veis_token', btsss_token: 'btsss_token' }) }
    let(:service) { described_class.new(auth_manager) }

    # Access private method for testing
    def build_request_body(params)
      service.send(:build_expense_request_body, params)
    end

    context 'snake_case to camelCase conversion' do
      it 'converts standard fields to camelCase' do
        params = {
          'expense_type' => 'lodging',
          'claim_id' => 'claim-123',
          'description' => 'Test description',
          'cost_requested' => 100.0
        }

        result = build_request_body(params)

        expect(result['expenseType']).to eq('lodging')
        expect(result['claimId']).to eq('claim-123')
        expect(result['description']).to eq('Test description')
        expect(result['costRequested']).to eq(100.0)
      end

      it 'handles special mappings for purchase_date' do
        params = { 'purchase_date' => '2024-11-01' }

        result = build_request_body(params)

        expect(result['dateIncurred']).to eq('2024-11-01')
        expect(result['purchaseDate']).to be_nil
      end

      it 'handles special mappings for receipt' do
        receipt_hash = {
          'content_type' => 'application/pdf',
          'content_length' => '12345',
          'file_data' => 'base64encodeddata',
          'file_type' => 'pdf'
        }
        params = { 'receipt' => receipt_hash }

        result = build_request_body(params)

        # Verify receipt is renamed to expenseReceipt
        expect(result['expenseReceipt']).to be_present
        expect(result['receipt']).to be_nil

        # Verify nested keys are also camelCased
        expect(result['expenseReceipt']['contentType']).to eq('application/pdf')
        expect(result['expenseReceipt']['contentLength']).to eq('12345')
        expect(result['expenseReceipt']['fileData']).to eq('base64encodeddata')
        expect(result['expenseReceipt']['fileType']).to eq('pdf')
      end

      it 'skips nil values' do
        params = {
          'expense_type' => 'lodging',
          'description' => nil,
          'cost_requested' => 100.0
        }

        result = build_request_body(params)

        expect(result['expenseType']).to eq('lodging')
        expect(result['costRequested']).to eq(100.0)
        expect(result).not_to have_key('description')
      end

      it 'handles Symbol keys correctly' do
        params = {
          expense_type: 'lodging',
          claim_id: 'claim-123',
          description: 'Test description',
          cost_requested: 100.0,
          purchase_date: '2024-11-01'
        }

        result = build_request_body(params)

        expect(result['expenseType']).to eq('lodging')
        expect(result['claimId']).to eq('claim-123')
        expect(result['description']).to eq('Test description')
        expect(result['costRequested']).to eq(100.0)
        expect(result['dateIncurred']).to eq('2024-11-01')
      end

      it 'handles mixed String and Symbol keys' do
        params = {
          'expense_type' => 'meal',
          claim_id: 'claim-456',
          'description' => 'Lunch',
          cost_requested: 25.0
        }

        result = build_request_body(params)

        expect(result['expenseType']).to eq('meal')
        expect(result['claimId']).to eq('claim-456')
        expect(result['description']).to eq('Lunch')
        expect(result['costRequested']).to eq(25.0)
      end
    end

    context 'mileage expense specific fields' do
      it 'converts mileage-specific fields correctly' do
        params = {
          'expense_type' => 'mileage',
          'purchase_date' => '2024-11-01',
          'trip_type' => 'RoundTrip',
          'requested_mileage' => 50.5,
          'claim_id' => 'claim-123'
        }

        result = build_request_body(params)

        expect(result).to eq({
                               'expenseType' => 'mileage',
                               'dateIncurred' => '2024-11-01',
                               'tripType' => 'RoundTrip',
                               'requestedMileage' => 50.5,
                               'claimId' => 'claim-123'
                             })
      end

      it 'does not include description or cost_requested for mileage' do
        params = {
          'expense_type' => 'mileage',
          'purchase_date' => '2024-11-01',
          'trip_type' => 'RoundTrip',
          'requested_mileage' => 50.5
        }

        result = build_request_body(params)

        expect(result).not_to have_key('description')
        expect(result).not_to have_key('costRequested')
      end
    end

    context 'lodging expense specific fields' do
      it 'converts lodging-specific fields correctly' do
        params = {
          'expense_type' => 'lodging',
          'purchase_date' => '2024-11-01',
          'description' => 'Hotel stay',
          'cost_requested' => 150.00,
          'vendor' => 'Hilton',
          'check_in_date' => '2024-11-01',
          'check_out_date' => '2024-11-02',
          'claim_id' => 'claim-123'
        }

        result = build_request_body(params)

        expect(result).to eq({
                               'expenseType' => 'lodging',
                               'dateIncurred' => '2024-11-01',
                               'description' => 'Hotel stay',
                               'costRequested' => 150.00,
                               'vendor' => 'Hilton',
                               'checkInDate' => '2024-11-01',
                               'checkOutDate' => '2024-11-02',
                               'claimId' => 'claim-123'
                             })
      end
    end

    context 'meal expense specific fields' do
      it 'converts meal-specific fields correctly' do
        params = {
          'expense_type' => 'meal',
          'purchase_date' => '2024-11-01',
          'description' => 'Lunch',
          'cost_requested' => 25.00,
          'vendor_name' => 'Restaurant ABC',
          'claim_id' => 'claim-123'
        }

        result = build_request_body(params)

        expect(result).to eq({
                               'expenseType' => 'meal',
                               'dateIncurred' => '2024-11-01',
                               'description' => 'Lunch',
                               'costRequested' => 25.00,
                               'vendorName' => 'Restaurant ABC',
                               'claimId' => 'claim-123'
                             })
      end
    end

    context 'flight expense specific fields' do
      it 'converts flight-specific fields correctly' do
        params = {
          'expense_type' => 'airtravel',
          'purchase_date' => '2024-11-01',
          'description' => 'Flight to appointment',
          'cost_requested' => 350.00,
          'vendor' => 'Delta',
          'trip_type' => 'RoundTrip',
          'departure_location' => 'LAX',
          'arrival_location' => 'JFK',
          'departure_date' => '2024-11-01T08:00:00',
          'arrival_date' => '2024-11-01T16:00:00',
          'claim_id' => 'claim-123'
        }

        result = build_request_body(params)

        expect(result).to eq({
                               'expenseType' => 'airtravel',
                               'dateIncurred' => '2024-11-01',
                               'description' => 'Flight to appointment',
                               'costRequested' => 350.00,
                               'vendor' => 'Delta',
                               'tripType' => 'RoundTrip',
                               'departureLocation' => 'LAX',
                               'arrivalLocation' => 'JFK',
                               'departureDate' => '2024-11-01T08:00:00',
                               'arrivalDate' => '2024-11-01T16:00:00',
                               'claimId' => 'claim-123'
                             })
      end
    end

    context 'common carrier expense specific fields' do
      it 'converts common carrier-specific fields correctly' do
        params = {
          'expense_type' => 'commoncarrier',
          'purchase_date' => '2024-11-01',
          'description' => 'Bus fare',
          'cost_requested' => 15.00,
          'reason_not_using_pov' => 'NoVehicle',
          'carrier_type' => 'Bus',
          'claim_id' => 'claim-123'
        }

        result = build_request_body(params)

        expect(result).to eq({
                               'expenseType' => 'commoncarrier',
                               'dateIncurred' => '2024-11-01',
                               'description' => 'Bus fare',
                               'costRequested' => 15.00,
                               'reasonNotUsingPOV' => 'NoVehicle',
                               'carrierType' => 'Bus',
                               'claimId' => 'claim-123'
                             })
      end
    end

    context 'parking expense (base expense fields only)' do
      it 'converts parking expense fields correctly' do
        params = {
          'expense_type' => 'parking',
          'purchase_date' => '2024-11-01',
          'description' => 'Parking fee',
          'cost_requested' => 10.00,
          'claim_id' => 'claim-123'
        }

        result = build_request_body(params)

        expect(result).to eq({
                               'expenseType' => 'parking',
                               'dateIncurred' => '2024-11-01',
                               'description' => 'Parking fee',
                               'costRequested' => 10.00,
                               'claimId' => 'claim-123'
                             })
      end
    end

    context 'toll expense (base expense fields only)' do
      it 'converts toll expense fields correctly' do
        params = {
          'expense_type' => 'toll',
          'purchase_date' => '2024-11-01',
          'description' => 'Highway toll',
          'cost_requested' => 5.00,
          'claim_id' => 'claim-123'
        }

        result = build_request_body(params)

        expect(result).to eq({
                               'expenseType' => 'toll',
                               'dateIncurred' => '2024-11-01',
                               'description' => 'Highway toll',
                               'costRequested' => 5.00,
                               'claimId' => 'claim-123'
                             })
      end
    end

    context 'with receipts' do
      it 'converts receipt field to expenseReceipt' do
        receipt_hash = {
          'content_type' => 'application/pdf',
          'content_length' => '12345',
          'file_data' => 'base64encodeddata',
          'file_type' => 'pdf'
        }
        params = {
          'expense_type' => 'lodging',
          'purchase_date' => '2024-11-01',
          'description' => 'Hotel stay',
          'cost_requested' => 150.00,
          'receipt' => receipt_hash,
          'claim_id' => 'claim-123'
        }

        result = build_request_body(params)

        # Verify receipt is renamed to expenseReceipt
        expect(result['expenseReceipt']).to be_present
        expect(result).not_to have_key('receipt')

        # Verify nested keys are also camelCased
        expect(result['expenseReceipt']['contentType']).to eq('application/pdf')
        expect(result['expenseReceipt']['contentLength']).to eq('12345')
        expect(result['expenseReceipt']['fileData']).to eq('base64encodeddata')
        expect(result['expenseReceipt']['fileType']).to eq('pdf')
      end
    end
  end
end
