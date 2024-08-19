# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RepresentationManagement::V0::AccreditedEntitiesForAppointController', type: :request do
  let(:path) { '/representation_management/v0/accredited_entities_for_appoint' }

  before do
    Flipper.enable(:appoint_a_representative_enable_pdf)
  end

  context 'the response should be an empty array' do
    before do
      create(:accredited_individual, :with_location, full_name: 'Bob Law')
      create(:accredited_individual, :with_location, full_name: 'Bob Smith')
      create(:accredited_organization, :with_location, name: 'Bob Law Firm')
      create(:accredited_organization, :with_location, name: 'Bob Smith Firm')
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
      AccreditedIndividual.destroy_all
      AccreditedOrganization.destroy_all
      get path, params: { query: 'Zach' }
      parsed_response = JSON.parse(response.body)
      expect(parsed_response).to eq([])
    end
  end

  context 'when the search is valid' do
    it 'returns a array of individuals and organizations' do
      create(:accredited_individual, :with_location, full_name: 'Bob Law')
      create(:accredited_individual, :with_location, full_name: 'Bob Smith')
      create(:accredited_organization, :with_location, name: 'Bob Law Firm')
      create(:accredited_organization, :with_location, name: 'Bob Smith Firm')
      get path, params: { query: 'Bob' }

      parsed_response = JSON.parse(response.body)
      expect(parsed_response.size).to eq(4)
      expect(parsed_response[0]['data']['attributes']['full_name']).to eq('Bob Law')
      expect(parsed_response[1]['data']['attributes']['full_name']).to eq('Bob Smith')
      expect(parsed_response[2]['data']['attributes']['name']).to eq('Bob Law Firm')
      expect(parsed_response[3]['data']['attributes']['name']).to eq('Bob Smith Firm')
    end

    it 'returns a mixed array of individuals and organizations in Levenshtein order' do
      create(:accredited_individual, :with_location, full_name: 'aaaa')
      create(:accredited_individual, :with_location, full_name: 'aaaab')
      create(:accredited_individual, :with_location, full_name: 'aaaabc')
      create(:accredited_individual, :with_location, full_name: 'aaaabcd')
      create(:accredited_individual, :with_location, full_name: 'aaaabcde')
      create(:accredited_organization, :with_location, name: 'aaaa')
      create(:accredited_organization, :with_location, name: 'aaaab')
      create(:accredited_organization, :with_location, name: 'aaaabc')
      create(:accredited_organization, :with_location, name: 'aaaabcd')
      create(:accredited_organization, :with_location, name: 'aaaabcde')

      get path, params: { query: 'aaaa' }

      parsed_response = JSON.parse(response.body)
      names_and_full_names_in_order = parsed_response.map do |r|
        r['data']['attributes']['full_name'] || r['data']['attributes']['name']
      end
      all_full_names = parsed_response.map { |r| r['data']['attributes']['full_name'] }
      all_names = parsed_response.map { |r| r['data']['attributes']['name'] }

      expect(parsed_response.size).to eq(10)
      expect(all_full_names).to eq(%w[aaaa aaaab aaaabc aaaabcd aaaabcde])
      expect(all_names).to eq(%w[aaaa aaaab aaaabc aaaabcd aaaabcde])
      expect(names_and_full_names_in_order).to eq(%w[aaaa aaaa aaaab aaaab aaaabc aaaabc aaaabcd aaaabcd aaaabcde
                                                     aaaabcde])
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
