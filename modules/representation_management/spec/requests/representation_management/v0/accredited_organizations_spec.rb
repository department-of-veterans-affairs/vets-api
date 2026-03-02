# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RepresentationManagement::V0::AccreditedOrganizations', type: :request do
  let(:path) { '/representation_management/v0/accredited_organizations' }
  let!(:valid_accredited_org1) do
    create(:accredited_organization,
           poa_code: '000',
           name: 'My Org',
           phone: '555-555-5555',
           city: 'My City',
           state_code: 'WA',
           zip_code: '12345',
           zip_suffix: '6789',
           can_accept_digital_poa_requests: true)
  end
  let!(:valid_accredited_org2) do
    create(:accredited_organization,
           poa_code: '111',
           name: 'A Second Org',
           phone: '555-555-5555',
           city: 'My City',
           state_code: 'WA',
           zip_code: '12345',
           zip_suffix: '6789',
           can_accept_digital_poa_requests: false)
  end
  let!(:invalid_accredited_org) do
    create(:accredited_organization,
           poa_code: '222',
           name: 'zzz- My Third Org',
           phone: '555-555-5555',
           city: 'My City',
           state_code: 'WA',
           zip_code: '12345',
           zip_suffix: '6789',
           can_accept_digital_poa_requests: false)
  end
  let!(:valid_veteran_org1) do
    create(:veteran_organization,
           poa: '000',
           name: 'My Veteran Org',
           phone: '555-555-5555',
           city: 'My City',
           state_code: 'WA',
           zip_code: '12345',
           zip_suffix: '6789',
           can_accept_digital_poa_requests: true)
  end
  let!(:valid_veteran_org2) do
    create(:veteran_organization,
           poa: '111',
           name: 'A Second Veteran Org',
           phone: '555-555-5555',
           city: 'My City',
           state_code: 'WA',
           zip_code: '12345',
           zip_suffix: '6789',
           can_accept_digital_poa_requests: false)
  end
  let!(:invalid_veteran_org) do
    create(:veteran_organization,
           poa: '222',
           name: 'zzz- My Third Org',
           phone: '555-555-5555',
           city: 'My City',
           state_code: 'WA',
           zip_code: '12345',
           zip_suffix: '6789',
           can_accept_digital_poa_requests: false)
  end

  before do
    allow(Flipper).to receive(:enabled?).with(:find_a_representative_enabled).and_return(true)
  end

  context 'when the :find_a_representative_use_accredited_models feature is enabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:find_a_representative_use_accredited_models).and_return(true)
    end

    it 'returns the two valid accredited_organizations sorted by name asc' do
      get path

      parsed_response = JSON.parse(response.body)
      expect(parsed_response.size).to eq(2)

      expect(parsed_response[0]['data']['attributes']['name']).to eq('A Second Org')
      expect(parsed_response[1]['data']['attributes']['name']).to eq('My Org')
    end
  end

  context 'when the :find_a_representative_use_accredited_models feature is disabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:find_a_representative_use_accredited_models).and_return(false)
    end

    it 'returns the two valid veteran_organizations sorted by name asc' do
      get path

      parsed_response = JSON.parse(response.body)
      expect(parsed_response.size).to eq(2)

      expect(parsed_response[0]['data']['attributes']['name']).to eq('A Second Veteran Org')
      expect(parsed_response[1]['data']['attributes']['name']).to eq('My Veteran Org')
    end
  end

  context 'when the :find_a_representative_enabled feature is disabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:find_a_representative_enabled).and_return(false)
    end

    it 'returns a 404' do
      get path

      expect(response).to have_http_status(:not_found)
    end
  end
end
