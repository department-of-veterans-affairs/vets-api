# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::ExpensesClient do
  let(:user) { build(:user) }

  before do
    @stubs = Faraday::Adapter::Test::Stubs.new

    conn = Faraday.new do |c|
      c.adapter(:test, @stubs)
      c.response :json
      c.request :json
    end

    allow_any_instance_of(TravelPay::ExpensesClient).to receive(:connection).and_return(conn)
  end

  context '/expenses/mileage' do
    # POST add_expense
    it 'returns an expenseId from the /expenses/mileage endpoint' do
      expense_id = '3fa85f64-5717-4562-b3fc-2c963f66afa6'
      @stubs.post('/api/v1.1/expenses/mileage') do
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

      expect(actual_expense_id).to eq(expense_id)
    end
  end
end
