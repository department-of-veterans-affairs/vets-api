# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::MedicalCopays', type: :request do
  let(:current_user) { build(:user, :loa3, icn: 123) }

  before do
    sign_in_as(current_user)
  end

  describe 'index', skip: 'temporarily skipped' do
    it 'returns a formatted hash response' do
      VCR.use_cassette(
        'lighthouse/hcc/medical_copays_index_with_city',
        record: :new_episodes
      ) do
        get '/v1/medical_copays'

        response_body = JSON.parse(response.body)
        meta = response_body['meta']
        copay_summary = meta['copay_summary']
        data_element = response_body['data'].first

        expect(copay_summary.keys)
          .to eq(%w[total_current_balance copay_bill_count last_updated_on])

        expect(meta.keys)
          .to eq(%w[total page per_page copay_summary])

        expect(data_element['attributes'].keys)
          .to match_array(
            %w[
              url
              facility
              facilityId
              lastupdatedAt
              city
              externalId
              latestBillingRef
              currentBalance
              previousBalance
              previousUnpaidBalance
            ]
          )
      end
    end

    it 'handles auth error' do
      VCR.use_cassette('lighthouse/hcc/auth_error') do
        allow(Auth::ClientCredentials::JWTGenerator).to receive(:generate_token).and_return('fake-jwt')
        get '/v1/medical_copays'

        response_body = JSON.parse(response.body)
        errors = response_body['errors']

        expect(errors.first.keys).to eq(%w[error error_description status code title detail])
      end
    end

    it 'handles no records returned' do
      VCR.use_cassette('lighthouse/hcc/no_records') do
        allow(Auth::ClientCredentials::JWTGenerator).to receive(:generate_token).and_return('fake-jwt')
        get '/v1/medical_copays'

        response_body = JSON.parse(response.body)
        expect(response_body['data']).to eq([])
      end
    end
  end

  describe 'show' do
    let(:current_user) { build(:user, :loa3, icn: '32000551') }

    # Service uses Concurrent::Promises for parallel API calls, so we need:
    # - allow_playback_repeats: concurrent threads may replay same response
    # - match_requests_on: [:method, :uri] to handle request ordering differences
    let(:vcr_options) { { allow_playback_repeats: true, match_requests_on: %i[method uri] } }

    it 'returns copay detail for authenticated user' do
      VCR.use_cassette('lighthouse/hcc/copay_detail_success', vcr_options) do
        allow(Auth::ClientCredentials::JWTGenerator).to receive(:generate_token).and_return('fake-jwt')

        get '/v1/medical_copays/4-1abZUKu7LnbcQc'

        expect(response).to have_http_status(:ok)

        response_body = JSON.parse(response.body)
        data = response_body['data']

        expect(data['type']).to eq('medicalCopayDetails')
        expect(data['id']).to be_present
        expect(data['attributes'].keys).to match_array(
          %w[
            externalId
            facility
            billNumber
            status
            statusDescription
            invoiceDate
            paymentDueDate
            accountNumber
            originalAmount
            principalBalance
            interestBalance
            administrativeCostBalance
            principalPaid
            interestPaid
            administrativeCostPaid
            lineItems
            payments
          ]
        )
        expect(data['meta'].keys).to match_array(%w[line_item_count payment_count])
      end
    end

    it 'handles auth error' do
      VCR.use_cassette('lighthouse/hcc/auth_error', vcr_options) do
        allow(Auth::ClientCredentials::JWTGenerator).to receive(:generate_token).and_return('fake-jwt')

        get '/v1/medical_copays/4-1abZUKu7LnbcQc'

        response_body = JSON.parse(response.body)
        errors = response_body['errors']

        expect(errors.first.keys).to eq(%w[error error_description status code title detail])
      end
    end
  end
end
