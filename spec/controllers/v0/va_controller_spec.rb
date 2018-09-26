# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Facilities::VaController, type: :controller do
  blank_matcher = lambda { |r1, r2|
    r1.uri.match(r2.uri)
  }

  it 'should return a certain data shape' do
    VCR.use_cassette('facilities/va/ppms', match_requests_on: [blank_matcher], allow_playback_repeats: true) do
      get :provider_locator, address: '22033', bbox: [-78.11, 38.11, -76.11, 39.61]
      expect(response).to have_http_status(:ok)
      b = JSON.parse(response.body)
      expect(b['data']).to be_an(Array)
      expect(b['data'].length).to be > 0
      expect(b['data'][0]['id']).not_to be(nil)
      expect(b['data'][0]['type']).to eq('cc_provider')
      expect(b['data'][0]['attributes']).to be_an(Hash)
    end
  end

  it 'should reformat some stuff' do
    prov = { 'ProviderIdentifier' => 'a', 'ProviderName' => 'b',
             'Latitude' => 1, 'Longitude' => 2, 'ProviderAcceptingNewPatients' => true,
             'ProviderGender' => 'c', 'Miles' => 3, 'ProviderNetwork' => 'd' }
    prov_info = { 'AddressStreet' => 'e', 'AddressCity' => 'f', 'AddressStateProvince' => 'g',
                  'AddressPostalCode' => 'h', 'MainPhone' => 'i', 'OrganizationFax' => 'j',
                  'ContactMethod' => 'k',
                  'ProviderSpecialties' => [{ 'SpecialtyName' => 'l' }] }
    @controller = V0::Facilities::VaController.new
    form = @controller.send :format_provloc, prov, prov_info
    expect(form).to eq(id: 'ccp_a', type: 'cc_provider', attributes: {
                         unique_id: 'a', name: 'b', lat: 1, long: 2, address: {
                           street: 'e', city: 'f', state: 'g', zip: 'h'
                         },
                         phone: 'i', fax: 'j', website: nil, prefContact: 'k', accNewPatients: true,
                         gender: 'c', distance: 3, network: 'd', specialty: ['l']
                       })
  end

  it 'shouldn\'t throw any errors' do
    get :suggested, name_part: 'belvoir', type: ['health']
    expect(response).to have_http_status(:ok)
    # @controller = V0::Facilities::VaController.new
    # @controller.instance_eval{ @params = { name_part: 't', type: 'HEALTH'}; validate_types_name_part }
    expect(true).to eq(true)
  end
end
