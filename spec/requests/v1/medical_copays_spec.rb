# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::MedicalCopays', type: :request do
  let(:current_user) { build(:user, :loa3, icn: 123) }

  before do
    sign_in_as(current_user)
  end

  describe 'index' do
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
end
