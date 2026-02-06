# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RepresentationManagement::V0::AccreditedEntitiesForAppoint', type: :request do
  let(:path) { '/representation_management/v0/accredited_entities_for_appoint' }
  let!(:bob_law) { create(:accredited_individual, :with_location, first_name: 'Bob', last_name: 'Law') }
  let!(:bob_smith) { create(:accredited_individual, :with_location, first_name: 'Bob', last_name: 'Smith') }
  let!(:bob_law_firm) { create(:accredited_organization, :with_location, name: 'Bob Law Firm') }
  let!(:bob_smith_firm) { create(:accredited_organization, :with_location, name: 'Bob Smith Firm') }

  before do
    Flipper.enable(:appoint_a_representative_enable_pdf) # rubocop:disable Project/ForbidFlipperToggleInSpecs
  end

  context 'the response should be an empty array' do
    context 'when the query parameter is an empty string' do
      it 'returns an empty array' do
        get path, params: { query: '' }

        parsed_response = JSON.parse(response.body)
        expect(parsed_response).to eq([])
      end
    end

    context 'when the query parameter is not present' do
      it 'returns an empty array' do
        get path

        parsed_response = JSON.parse(response.body)
        expect(parsed_response).to eq([])
      end
    end

    it 'when there are no matching results' do
      get path, params: { query: 'Zach' }
      parsed_response = JSON.parse(response.body)
      expect(parsed_response).to eq([])
    end
  end

  context 'when the search is valid' do
    it 'returns a array of individuals and organizations' do
      get path, params: { query: 'Bob' }

      parsed_response = JSON.parse(response.body)
      expect(parsed_response.size).to eq(4)
      expect(parsed_response[0]['data']['attributes']['full_name']).to eq('Bob Law')
      expect(parsed_response[1]['data']['attributes']['full_name']).to eq('Bob Smith')
      expect(parsed_response[2]['data']['attributes']['name']).to eq('Bob Law Firm')
      expect(parsed_response[3]['data']['attributes']['name']).to eq('Bob Smith Firm')
    end
  end

  context "when the feature flag 'find_a_representative_use_accredited_models' is disabled" do
    before do
      Flipper.disable(:find_a_representative_use_accredited_models) # rubocop:disable Project/ForbidFlipperToggleInSpecs
    end

    after do
      Flipper.enable(:find_a_representative_use_accredited_models) # rubocop:disable Project/ForbidFlipperToggleInSpecs
    end

    it 'returns a 404' do
      get path

      expect(response).to have_http_status(:not_found)
    end
  end
end
