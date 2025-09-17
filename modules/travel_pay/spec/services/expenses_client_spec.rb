# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::ExpensesClient do
  let(:user) { build(:user) }
  let(:client) { described_class.new }
  let(:veis_token) { 'test_veis_token' }
  let(:btsss_token) { 'test_btsss_token' }

  expected_log_prefix = 'travel_pay.expense.response_time'
  before do
    @stubs = Faraday::Adapter::Test::Stubs.new

    conn = Faraday.new do |c|
      c.adapter(:test, @stubs)
      c.response :json
      c.request :json
    end

    allow_any_instance_of(TravelPay::ExpensesClient).to receive(:connection).and_return(conn)
    allow(StatsD).to receive(:measure)
    allow(Settings.travel_pay).to receive(:base_url).and_return('https://test-api.va.gov')
  end

  context '/expenses/mileage' do
    # POST add_expense
    it 'returns an expenseId from the /expenses/mileage endpoint' do
      expense_id = '3fa85f64-5717-4562-b3fc-2c963f66afa6'
      @stubs.post('/api/v2/expenses/mileage') do
        [
          200,
          {},
          {
            'data' =>
              {
                'expenseId' => expense_id
              }
          }
        ]
      end

      client = TravelPay::ExpensesClient.new
      new_expense_response = client.add_mileage_expense('veis_token', 'btsss_token',
                                                        { 'claimId' => 'fake_claim_id',
                                                          'dateIncurred' => '2024-10-02T14:36:38.043Z',
                                                          'tripType' => 'RoundTrip' }.to_json)
      actual_expense_id = new_expense_response.body['data']['expenseId']

      expect(StatsD).to have_received(:measure)
        .with(expected_log_prefix,
              kind_of(Numeric),
              tags: ['travel_pay:add_mileage'])
      expect(actual_expense_id).to eq(expense_id)
    end
  end

  describe '#add_expense' do
    let(:expense_body) do
      {
        'claimId' => 'test-claim-id',
        'dateIncurred' => '2024-01-15T10:30:00Z',
        'description' => 'Test expense',
        'amount' => 25.50
      }
    end

    let(:mock_response) do
      instance_double(Faraday::Response, body: { 'data' => { 'id' => 'expense-123' } })
    end

    before do
      allow(client).to receive_messages(connection: instance_double(Faraday::Connection, post: mock_response),
                                        claim_headers: {})
      allow(client).to receive(:log_to_statsd).and_yield
    end

    context 'for different expense types' do
      let(:connection_double) { instance_double(Faraday::Connection) }
      let(:request_double) { instance_double(Faraday::Request, headers: {}, body: nil) }

      before do
        allow(client).to receive(:connection).and_return(connection_double)
        allow(connection_double).to receive(:post).and_yield(request_double).and_return(mock_response)
        allow(request_double).to receive(:headers=)
        allow(request_double).to receive(:body=)
      end

      it 'routes mileage expenses to the correct endpoint' do
        mileage_expense = { 'claimId' => 'fake_claim_id',
                            'dateIncurred' => '2024-10-02T14:36:38.043Z',
                            'tripType' => 'RoundTrip' }
        expect(connection_double).to receive(:post).with('api/v2/expenses/mileage')

        client.add_mileage_expense(veis_token, btsss_token, mileage_expense)
      end

      it 'routes other expenses to the correct endpoint' do
        expect(connection_double).to receive(:post).with('api/v1/expenses/other')

        client.add_expense(veis_token, btsss_token, 'other', expense_body)
      end

      it 'raises an error when an unsupported expense type is provided' do
        expect { client.add_expense(veis_token, btsss_token, 'unknown_type', expense_body) }
          .to raise_error(ArgumentError, /Unsupported expense_type/)
      end
    end

    it 'sets the correct headers' do
      connection_double = instance_double(Faraday::Connection)
      request_double = instance_double(Faraday::Request)
      headers_hash = {}

      allow(connection_double).to receive(:post).and_yield(request_double).and_return(mock_response)
      allow(client).to receive_messages(connection: connection_double, claim_headers: { 'Custom-Header' => 'test' })
      allow(request_double).to receive(:headers).and_return(headers_hash)
      allow(request_double).to receive(:body=)

      client.add_expense(veis_token, btsss_token, 'meal', expense_body)

      expect(headers_hash['Authorization']).to eq("Bearer #{veis_token}")
      expect(headers_hash['BTSSS-Access-Token']).to eq(btsss_token)
      expect(headers_hash['X-Correlation-ID']).to be_present
    end

    it 'logs the expense type in statsd' do
      expect(client).to receive(:log_to_statsd).with('expense', 'add_meal')

      client.add_expense(veis_token, btsss_token, 'meal', expense_body)
    end
  end

  describe '#expense_endpoint_for_type' do
    it 'returns correct endpoints for each expense type' do
      expect(client.send(:expense_endpoint_for_type, 'other')).to eq('api/v1/expenses/other')
    end

    it 'raises an error for unsupported expense types' do
      expect { client.send(:expense_endpoint_for_type, 'unknown') }
        .to raise_error(ArgumentError, /Unsupported expense_type/)
    end
  end
end
