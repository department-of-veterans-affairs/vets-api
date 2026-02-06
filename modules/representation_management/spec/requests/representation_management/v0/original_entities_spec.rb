# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RepresentationManagement::V0::OriginalEntities', type: :request do
  let(:path) { '/representation_management/v0/original_entities' }
  let!(:bob_law) do
    create(:representative, :with_address, representative_id: '00001', first_name: 'Bob', last_name: 'Law')
  end
  let!(:bob_smith) do
    create(:representative, :with_address, representative_id: '00002', first_name: 'Bob', last_name: 'Smith')
  end
  let!(:bob_law_firm) { create(:organization, :with_address, poa: 'ABC', name: 'Bob Law Firm') }
  let!(:bob_smith_firm) { create(:organization, :with_address, poa: 'DEF', name: 'Bob Smith Firm') }

  context 'when use_veteran_models_for_appoint is disabled' do
    before do
      Flipper.disable(:use_veteran_models_for_appoint) # rubocop:disable Project/ForbidFlipperToggleInSpecs
    end

    it 'returns a not found routing error' do
      get path

      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when use_veteran_models_for_appoint is enabled' do
    before do
      Flipper.enable(:use_veteran_models_for_appoint) # rubocop:disable Project/ForbidFlipperToggleInSpecs
    end

    context 'when no query param is provided' do
      it 'returns an empty array' do
        get path

        parsed_response = JSON.parse(response.body)

        expect(response).to have_http_status(:success)
        expect(parsed_response).to eq([])
      end
    end

    context 'when the query string is blank' do
      it 'returns an empty array' do
        get path, params: { query: '' }

        parsed_response = JSON.parse(response.body)

        expect(response).to have_http_status(:success)
        expect(parsed_response).to eq([])
      end
    end

    context 'when the search yields no results' do
      it 'when there are no matching results' do
        get path, params: { query: 'Zach' }

        parsed_response = JSON.parse(response.body)

        expect(response).to have_http_status(:success)
        expect(parsed_response).to eq([])
      end
    end

    context 'when there are search results'  do
      it 'returns a array of individuals and organizations' do
        get path, params: { query: 'Bob' }

        parsed_response = JSON.parse(response.body)

        expect(response).to have_http_status(:success)
        expect(parsed_response.size).to eq(4)
        expect(parsed_response[0]['data']['attributes']['full_name']).to eq('Bob Law')
        expect(parsed_response[1]['data']['attributes']['full_name']).to eq('Bob Smith')
        expect(parsed_response[2]['data']['attributes']['name']).to eq('Bob Law Firm')
        expect(parsed_response[3]['data']['attributes']['name']).to eq('Bob Smith Firm')
      end
    end
  end
end
