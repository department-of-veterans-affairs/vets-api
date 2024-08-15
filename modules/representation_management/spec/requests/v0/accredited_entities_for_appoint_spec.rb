# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RepresentationManagement::V0::AccreditedEntitiesForAppointController', type: :request do
  let(:path) { '/representation_management/v0/accredited_entities_for_appoint' }

  before do
    Flipper.enable(:appoint_a_representative_enable_pdf)
  end

  context 'the response should be an empty array' do
    before do
      create(:accredited_individual, full_name: 'Bob Law')
      create(:accredited_individual, full_name: 'Bob Smith')
      create(:accredited_organization, name: 'Bob Law Firm')
      create(:accredited_organization, name: 'Bob Smith Firm')
    end

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
      create(:accredited_individual, full_name: 'Bob Law')
      create(:accredited_individual, full_name: 'Bob Smith')
      create(:accredited_organization, name: 'Bob Law Firm')
      create(:accredited_organization, name: 'Bob Smith Firm')
      get path, params: { query: 'Bob' }

      parsed_response = JSON.parse(response.body)
      expect(parsed_response.size).to eq(4)
      expect(parsed_response[0]['data']['attributes']['full_name']).to eq('Bob Law')
      expect(parsed_response[1]['data']['attributes']['full_name']).to eq('Bob Smith')
      expect(parsed_response[2]['data']['attributes']['name']).to eq('Bob Law Firm')
      expect(parsed_response[3]['data']['attributes']['name']).to eq('Bob Smith Firm')
    end

    it 'returns a mixed array of individuals and organizations in Levenshtein order' do
      create(:accredited_individual, full_name: 'aaaa')
      create(:accredited_individual, full_name: 'aaaab')
      create(:accredited_individual, full_name: 'aaaabc')
      create(:accredited_individual, full_name: 'aaaabcd')
      create(:accredited_individual, full_name: 'aaaabcde')
      create(:accredited_organization, name: 'aaaa')
      create(:accredited_organization, name: 'aaaab')
      create(:accredited_organization, name: 'aaaabc')
      create(:accredited_organization, name: 'aaaabcd')
      create(:accredited_organization, name: 'aaaabcde')

      get path, params: { query: 'aaaa' }

      parsed_response = JSON.parse(response.body)
      expect(parsed_response.size).to eq(10)
      expect(parsed_response[0]['data']['attributes']['full_name']).to eq('aaaa')
      expect(parsed_response[1]['data']['attributes']['name']).to eq('aaaa')
      expect(parsed_response[2]['data']['attributes']['full_name']).to eq('aaaab')
      expect(parsed_response[3]['data']['attributes']['name']).to eq('aaaab')
      expect(parsed_response[4]['data']['attributes']['full_name']).to eq('aaaabc')
      expect(parsed_response[5]['data']['attributes']['name']).to eq('aaaabc')
      expect(parsed_response[6]['data']['attributes']['full_name']).to eq('aaaabcd')
      expect(parsed_response[7]['data']['attributes']['name']).to eq('aaaabcd')
      expect(parsed_response[8]['data']['attributes']['full_name']).to eq('aaaabcde')
      expect(parsed_response[9]['data']['attributes']['name']).to eq('aaaabcde')
    end
  end

  context "when the feature flag 'appoint_a_representative_enable_pdf' is disabled" do
    before do
      Flipper.disable(:appoint_a_representative_enable_pdf)
    end

    after do
      Flipper.enable(:appoint_a_representative_enable_pdf)
    end

    it 'returns a 404' do
      get path

      expect(response).to have_http_status(:not_found)
    end
  end
end
