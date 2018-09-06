# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Facilities::CcpController, type: :controller do
  blank_matcher = lambda { |r1, r2|
    r1.uri.match(r2.uri)
  }

  it 'should 200' do
    VCR.use_cassette('facilities/va/ppms', match_requests_on: [blank_matcher]) do
      get :ppms, params: { Command: 'Providers', Identifier: '12345' }
      expect(response).to have_http_status(:ok)
    end
  end

  it 'should have a certain shape' do
    VCR.use_cassette('facilities/va/ppms', match_requests_on: [blank_matcher]) do
      get 'show', id: 12_345
      puts(response.body)
      expect(response).to have_http_status(:ok)
      bod = JSON.parse(response.body)
      expect(bod['id']).to include('ccp_')
      expect(bod['type']).to eq('cc_provider')
    end
  end

  it 'should reformat some stuff' do
    prov_info = { 'AddressStreet' => 'e', 'AddressCity' => 'f', 'AddressStateProvince' => 'g',
                  'AddressPostalCode' => 'h', 'MainPhone' => 'i', 'OrganizationFax' => 'j',
                  'ContactMethod' => 'k', 'ProviderIdentifier' => 'a', 'Name' => 'b',
                  'IsAcceptingNewPatients' => true, 'ProviderGender' => 'c',
                  'ProviderSpecialties' => [{ 'SpecialtyName' => 'l' }] }
    @controller = V0::Facilities::CcpController.new
    form = @controller.send :format_details, prov_info
    expect(form).to eq(id: 'ccp_a', type: 'cc_provider', attributes: {
                         unique_id: 'a', name: 'b', orgName: nil, address: {
                           street: 'e', city: 'f', state: 'g', zip: 'h'
                         },
                         phone: 'i', fax: 'j', website: nil, prefContact: 'k', accNewPatients: true,
                         gender: 'c', network: nil, specialty: ['l']
                       })
  end
end
