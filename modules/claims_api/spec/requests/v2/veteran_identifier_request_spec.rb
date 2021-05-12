# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Veteran Identifier Endpoint', type: :request do
  let(:path) { '/services/claims/v2/veteran-identifier' }

  context 'when all headers are present' do
    let(:headers) do
      {
        'Authorization': 'Bearer somerandomstuff',
        'X-VA-SSN': '796-04-3735',
        'X-VA-First-Name': 'WESLEY',
        'X-VA-Last-Name': 'FORD',
        'X-VA-Birth-Date': '1986-05-06T00:00:00+00:00'
      }
    end

    describe 'veteran identifier' do
      it 'returns an id' do
        get path, headers: headers
        icn = JSON.parse(response.body)['id']
        expect(icn).to eq(ClaimsApi::V2::VeteranIdentifierController::ICN_FOR_TEST_USER)
        expect(response.status).to eq(200)
      end
    end
  end

  context 'when all headers are not present' do
    let(:headers) do
      {
        'X-VA-SSN': '796-04-3735',
        'X-VA-First-Name': 'WESLEY',
        'X-VA-Last-Name': 'FORD',
        'X-VA-Birth-Date': '1986-05-06T00:00:00+00:00'
      }
    end

    describe 'veteran identifier' do
      it 'returns a 400 error code' do
        get path, headers: headers
        expect(response.status).to eq(400)
      end
    end
  end
end
