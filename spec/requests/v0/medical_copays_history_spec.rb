# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::MedicalCopaysHistory', type: :request do
  let(:current_user) { build(:user, :loa3, icn: 123) }

  before do
    sign_in_as(current_user)
  end

  describe 'index' do
    it 'returns a formatted hash response' do
      VCR.use_cassette('lighthouse/hccc/invoice_list_success') do
        get '/v0/medical_copays_history'
        response_body = JSON.parse(response.body)
        data_element = response_body['data'].first
        expect(data_element['attributes'].keys).to match_array(
          %w[
            id
            url
            facility
            externalId
            billingRef
            currentBalance
            previousBalance
            previousUnpaidBalance
          ]
        )
      end
    end

    it 'handles auth error' do
      VCR.use_cassette('lighthouse/hccc/auth_error') do
        allow(Auth::ClientCredentials::JWTGenerator).to receive(:generate_token).and_return('fake-jwt')
        get '/v0/medical_copays_history'

        response_body = JSON.parse(response.body)
        errors = response_body['errors']

        expect(errors.first.keys).to eq(["error", "error_description", "status", "code", "title", "detail"])
      end
    end

    it 'handles no records returned' do
      VCR.use_cassette('lighthouse/hccc/no_records') do
        allow(Auth::ClientCredentials::JWTGenerator).to receive(:generate_token).and_return('fake-jwt')
        get '/v0/medical_copays_history'

        response_body = JSON.parse(response.body)
        expect(response_body['data']).to eq([])
      end
    end
  end
end
