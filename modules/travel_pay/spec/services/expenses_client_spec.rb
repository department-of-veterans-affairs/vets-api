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

  describe '#add_mileage_expense' do
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

      it 'routes other expenses to the correct endpoint' do
        expect(connection_double).to receive(:post).with('api/v1/expenses/other')

        client.add_expense(veis_token, btsss_token, 'other', expense_body)
      end

      it 'raises an error when an unsupported expense type is provided' do
        expect { client.add_expense(veis_token, btsss_token, 'unknown_type', expense_body) }
          .to raise_error(ArgumentError, /Unsupported expense type: unknown_type/)
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

      client.add_expense(veis_token, btsss_token, 'other', expense_body)

      expect(headers_hash['Authorization']).to eq("Bearer #{veis_token}")
      expect(headers_hash['BTSSS-Access-Token']).to eq(btsss_token)
      expect(headers_hash['X-Correlation-ID']).to be_present
    end

    it 'logs the expense type in statsd' do
      expect(client).to receive(:log_to_statsd).with('expense', 'add_other')

      client.add_expense(veis_token, btsss_token, 'other', expense_body)
    end
  end

  describe '#get_expense' do
    let(:expense_id) { 'test-expense-id' }
    let(:mock_response) do
      instance_double(Faraday::Response, body: { 'data' => { 'id' => expense_id } })
    end

    before do
      allow(client).to receive_messages(connection: instance_double(Faraday::Connection, get: mock_response),
                                        claim_headers: {})
      allow(client).to receive(:log_to_statsd).and_yield
    end

    context 'for different expense types' do
      let(:connection_double) { instance_double(Faraday::Connection) }
      let(:request_double) { instance_double(Faraday::Request, headers: {}) }

      before do
        allow(client).to receive(:connection).and_return(connection_double)
        allow(connection_double).to receive(:get).and_yield(request_double).and_return(mock_response)
        allow(request_double).to receive(:headers=)
      end

      it 'routes other expenses to the correct endpoint' do
        expect(connection_double).to receive(:get).with("api/v1/expenses/other/#{expense_id}")

        client.get_expense(veis_token, btsss_token, 'other', expense_id)
      end

      it 'raises error for unsupported expense types' do
        expect do
          client.get_expense(veis_token, btsss_token, 'unknown_type',
                             expense_id)
        end.to raise_error(ArgumentError, /Unsupported expense type/)
      end
    end

    it 'sets the correct headers' do
      connection_double = instance_double(Faraday::Connection)
      request_double = instance_double(Faraday::Request)
      headers_hash = {}

      allow(connection_double).to receive(:get).and_yield(request_double).and_return(mock_response)
      allow(client).to receive_messages(connection: connection_double, claim_headers: { 'Custom-Header' => 'test' })
      allow(request_double).to receive(:headers).and_return(headers_hash)

      client.get_expense(veis_token, btsss_token, 'other', expense_id)

      expect(headers_hash['Authorization']).to eq("Bearer #{veis_token}")
      expect(headers_hash['BTSSS-Access-Token']).to eq(btsss_token)
      expect(headers_hash['X-Correlation-ID']).to be_present
    end

    it 'logs the expense type in statsd' do
      expect(client).to receive(:log_to_statsd).with('expense', 'get_other')

      client.get_expense(veis_token, btsss_token, 'other', expense_id)
    end
  end

  describe '#delete_expense' do
    let(:expense_id) { '3fa85f64-5717-4562-b3fc-2c963f66afa6' }
    let(:connection_double) { instance_double(Faraday::Connection) }
    let(:response_body) { { 'data' => { 'id' => expense_id }, 'success' => true } }
    let(:mock_response) do
      instance_double(Faraday::Response, body: response_body)
    end

    before do
      allow(client).to receive_messages(
        connection: connection_double,
        claim_headers: {}
      )
      allow(client).to receive(:log_to_statsd).and_yield
    end

    it 'deletes an other expense type and returns a success response' do
      request_double = double('request', headers: {})

      expect(connection_double).to receive(:delete)
        .with("api/v1/expenses/other/#{expense_id}")
        .and_yield(request_double)
        .and_return(mock_response)

      response = client.delete_expense(veis_token, btsss_token, expense_id, 'other')
      expect(response.body['success']).to be(true)
      expect(response.body['data']['id']).to eq(expense_id)
    end

    it 'raises an error when expense_id is not a valid UUID' do
      expect { client.delete_expense(veis_token, btsss_token, 'not-a-uuid', 'other') }
        .to raise_error(ArgumentError, /Invalid expense_id/)
    end

    it 'raises an error when expense type is unsupported' do
      expect { client.delete_expense(veis_token, btsss_token, expense_id, 'unknown_type') }
        .to raise_error(ArgumentError, /Unsupported expense type: unknown_type/)
    end

    it 'sets the correct headers' do
      headers_hash = {}
      request_double = double(headers: headers_hash)
      mock_response = instance_double(Faraday::Response, status: 200, body: {})

      allow(connection_double).to receive(:delete)
        .with("api/v1/expenses/other/#{expense_id}")
        .and_yield(request_double)
        .and_return(mock_response)

      client.delete_expense(veis_token, btsss_token, expense_id, 'other')

      expect(headers_hash['Authorization']).to eq("Bearer #{veis_token}")
      expect(headers_hash['BTSSS-Access-Token']).to eq(btsss_token)
      expect(headers_hash['X-Correlation-ID']).to be_present
    end

    context 'when the API responds with errors' do
      it 'raises BadRequest on 400' do
        allow(connection_double).to receive(:delete)
          .and_raise(Faraday::BadRequestError.new(nil))

        expect do
          client.delete_expense(veis_token, btsss_token, expense_id, 'other')
        end.to raise_error(Faraday::BadRequestError)
      end

      it 'raises Forbidden on 403' do
        allow(connection_double).to receive(:delete)
          .and_raise(Faraday::ForbiddenError.new(nil))

        expect do
          client.delete_expense(veis_token, btsss_token, expense_id, 'other')
        end.to raise_error(Faraday::ForbiddenError)
      end

      it 'raises ResourceNotFound on 404' do
        allow(connection_double).to receive(:delete)
          .and_raise(Faraday::ResourceNotFound.new(nil))

        expect do
          client.delete_expense(veis_token, btsss_token, expense_id, 'other')
        end.to raise_error(Faraday::ResourceNotFound)
      end

      it 'raises ServerError on 500' do
        allow(connection_double).to receive(:delete)
          .and_raise(Faraday::ServerError.new(nil))

        expect do
          client.delete_expense(veis_token, btsss_token, expense_id, 'other')
        end.to raise_error(Faraday::ServerError)
      end
    end
  end

  describe '#update_expense' do
    let(:expense_id) { '3fa85f64-5717-4562-b3fc-2c963f66afa6' }
    let(:expense_body) do
      {
        'claimId' => 'test-claim-id',
        'dateIncurred' => '2024-01-15T10:30:00Z',
        'description' => 'Test expense',
        'amount' => 25.50
      }
    end
    let(:connection_double) { instance_double(Faraday::Connection) }
    let(:response_body) { { 'data' => { 'id' => expense_id }, 'success' => true } }
    let(:mock_response) do
      instance_double(Faraday::Response, body: response_body)
    end

    before do
      allow(client).to receive_messages(
        connection: connection_double,
        claim_headers: {}
      )
      allow(client).to receive(:log_to_statsd).and_yield
    end

    it 'updates an other expense type and returns a success response' do
      request_double = double('request', headers: {})
      allow(request_double).to receive(:body=)

      expect(connection_double).to receive(:patch)
        .with("api/v1/expenses/other/#{expense_id}")
        .and_yield(request_double)
        .and_return(mock_response)

      response = client.update_expense(veis_token, btsss_token, expense_id, 'other', expense_body)
      expect(response.body['success']).to be(true)
      expect(response.body['data']['id']).to eq(expense_id)
    end

    it 'raises an error when expense_id is not a valid UUID' do
      expect { client.update_expense(veis_token, btsss_token, 'not-a-uuid', 'other', expense_body) }
        .to raise_error(ArgumentError, /Invalid expense_id/)
    end

    it 'raises an error when expense type is unsupported' do
      expect { client.update_expense(veis_token, btsss_token, expense_id, 'unknown_type', expense_body) }
        .to raise_error(ArgumentError, /Unsupported expense type: unknown_type/)
    end

    it 'sets the correct headers' do
      headers_hash = {}
      request_double = double(headers: headers_hash)
      mock_response = instance_double(Faraday::Response, status: 200, body: {})
      allow(request_double).to receive(:body=)

      allow(connection_double).to receive(:patch)
        .with("api/v1/expenses/other/#{expense_id}")
        .and_yield(request_double)
        .and_return(mock_response)

      client.update_expense(veis_token, btsss_token, expense_id, 'other', expense_body)

      expect(headers_hash['Authorization']).to eq("Bearer #{veis_token}")
      expect(headers_hash['BTSSS-Access-Token']).to eq(btsss_token)
      expect(headers_hash['X-Correlation-ID']).to be_present
    end

    context 'when the API responds with errors' do
      it 'raises BadRequest on 400' do
        allow(connection_double).to receive(:patch)
          .and_raise(Faraday::BadRequestError.new(nil))

        expect do
          client.update_expense(veis_token, btsss_token, expense_id, 'other', expense_body)
        end.to raise_error(Faraday::BadRequestError)
      end

      it 'raises Forbidden on 403' do
        allow(connection_double).to receive(:patch)
          .and_raise(Faraday::ForbiddenError.new(nil))

        expect do
          client.update_expense(veis_token, btsss_token, expense_id, 'other', expense_body)
        end.to raise_error(Faraday::ForbiddenError)
      end

      it 'raises ResourceNotFound on 404' do
        allow(connection_double).to receive(:patch)
          .and_raise(Faraday::ResourceNotFound.new(nil))

        expect do
          client.update_expense(veis_token, btsss_token, expense_id, 'other', expense_body)
        end.to raise_error(Faraday::ResourceNotFound)
      end

      it 'raises ServerError on 500' do
        allow(connection_double).to receive(:patch)
          .and_raise(Faraday::ServerError.new(nil))

        expect do
          client.update_expense(veis_token, btsss_token, expense_id, 'other', expense_body)
        end.to raise_error(Faraday::ServerError)
      end
    end
  end
end
