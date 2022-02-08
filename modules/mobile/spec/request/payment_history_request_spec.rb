# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'payment_history', type: :request do
  include JsonSchemaMatchers

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  before { iam_sign_in }

  describe 'GET /mobile/v0/payment-history' do
    context 'with successful response' do
      before do
        VCR.use_cassette('payment_history/retrieve_payment_summary_with_bdn', match_requests_on: %i[method uri]) do
          get '/mobile/v0/payment-history', headers: iam_headers, params: nil
        end
      end

      it 'returns 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'matches expected schema' do
        expect(response.body).to match_json_schema('payment_history')
      end

      it 'includes the expected properties for payment history' do
        expect(response.parsed_body['data'].first).to include(
          {
            'id' => '11213114',
            'type' => 'payment_history',
            'attributes' => {
              'amount' => '$3,444.70',
              'date' => '2019-12-31T00:00:00.000-06:00',
              'paymentMethod' => 'Direct Deposit',
              'paymentType' => 'Compensation & Pension - Recurring',
              'bank' => 'BANK OF AMERICA, N.A.',
              'account' => '**3456'
            }
          }
        )
      end
    end

    context 'with a missing address_eft or account_number' do
      let(:page) { { number: 5, size: 10 } }
      let(:params) { { page: page } }

      before do
        VCR.use_cassette('payment_history/retrieve_payment_summary_with_bdn', match_requests_on: %i[method uri]) do
          get '/mobile/v0/payment-history', headers: iam_headers, params: params
        end
      end

      it 'returns nil when address_eft or account_number is blank' do
        attributes = response.parsed_body.dig('data', 5, 'attributes')
        expect(attributes['account']).to be_nil
      end
    end

    context 'when address_eft and account_number has value' do
      let(:page) { { number: 1, size: 10 } }
      let(:params) { { page: page } }

      before do
        VCR.use_cassette('payment_history/retrieve_payment_summary_with_bdn', match_requests_on: %i[method uri]) do
          get '/mobile/v0/payment-history', headers: iam_headers, params: params
        end
      end

      it 'returns account value when address_eft and account_number have value' do
        attributes = response.parsed_body.dig('data', 5, 'attributes')
        expect(attributes['account']).not_to be_nil
      end
    end

    context 'with invalid params' do
      let(:params) { { page: { number: 'one', size: 'ten' } } }

      before do
        VCR.use_cassette('payment_history/retrieve_payment_summary_with_bdn', match_requests_on: %i[method uri]) do
          get '/mobile/v0/payment-history', headers: iam_headers, params: params
        end
      end

      it 'returns a 422' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'lists the invalid params' do
        expect(response.parsed_body).to eq(
          {
            'errors' =>
              [
                {
                  'title' => 'Validation Error',
                  'detail' => 'page_number must be an integer',
                  'code' => 'MOBL_422_validation_error', 'status' => '422'
                },
                {
                  'title' => 'Validation Error',
                  'detail' => 'page_size must be an integer',
                  'code' => 'MOBL_422_validation_error', 'status' => '422'
                }
              ]
          }
        )
      end
    end
  end
end
