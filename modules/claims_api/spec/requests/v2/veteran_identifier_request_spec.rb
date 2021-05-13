# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Veteran Identifier Endpoint', type: :request do
  let(:path) { '/services/benefits/v2/veteran-id:find' }
  let(:headers) { { 'Authorization': 'Bearer somerandomstuff' } }
  let(:data) { File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'veteran_identifier.json')) }

  context 'when auth header and body params are present' do
    describe 'veteran identifier' do
      it 'returns an id' do
        post path, params: data, headers: headers
        icn = JSON.parse(response.body)['id']
        expect(icn).to eq(ClaimsApi::V2::VeteranIdentifierController::ICN_FOR_TEST_USER)
        expect(response.status).to eq(200)
      end
    end
  end

  context 'when body params are not present' do
    let(:data) { nil }

    describe 'veteran identifier' do
      it 'returns a 422 error code' do
        post path, params: data, headers: headers
        expect(response.status).to eq(422)
      end
    end
  end

  context 'when auth header is not present' do
    let(:headers) { nil }

    describe 'veteran identifier' do
      it 'returns a 400 error code' do
        post path, params: data
        expect(response.status).to eq(400)
      end
    end
  end
end
