# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RepresentationManagement::V0::AccreditedEntitiesForAppointController', type: :request do
  let(:path) { '/representation_management/v0/accredited_entities_for_appoint' }

  before do
    Flipper.enable(:appoint_a_representative_enable_pdf)
  end

  context 'when the query parameter is an empty string' do
    it 'returns an empty list' do
      get path, params: { query: '' }

      parsed_response = JSON.parse(response.body)
      expect(parsed_response).to eq('data' => [])
    end
  end

  context 'when the query parameter is not present' do
    it 'returns an empty list' do
      get path

      parsed_response = JSON.parse(response.body)
      expect(parsed_response).to eq('data' => [])
    end
  end

  context 'when the search is valid' do
    let!(:individual) { create(:accredited_individual, full_name: 'Bob Law') }
    let!(:organization) { create(:accredited_organization, name: 'Bob Law Firm') }

    it 'returns a list of individuals and organizations' do
      get path, params: { query: 'Bob' }

      parsed_response = JSON.parse(response.body)
      p "parsed_response: #{parsed_response}", "parsed_response.class.name: #{parsed_response.class.name}"
      p "parsed_response.size: #{parsed_response.size}"
      p "parsed_response.first.class: #{parsed_response.first.class.name}"
      expect(parsed_response.size).to eq(2)

      expect(parsed_response.first['attributes']['type']).to eq('accredited_individuals')
      expect(parsed_response.first['attributes']['full_name']).to eq('Bob Law')

      expect(parsed_response[1]['type']).to eq('accredited_organizations')
      expect(parsed_response[1]['attributes']['name']).to eq('Bob Law Firm')
    end
  end
end
