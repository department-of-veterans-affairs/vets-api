# frozen_string_literal: true

require 'rails_helper'
require 'facilities/ppms/response'

describe Facilities::PPMS::Response do
  let(:provider_locator_body) do
    [
      {
        'Miles' => 7.47076307768083,
        'Minutes' => 11.5083333333333,
        'ProviderName' => 'DOCTOR PARTNERS OF NORTHERN VIRGINIA',
        'ProviderSpecialty' => 'Allergy & Immunology   ',
        'SpecialtyCode' => '207K00000X',
        'CareSite' => '4229 LAFAYETTE CENTER DR,UNIT 1760,CHANTILLY,VA,20151',
        'CareSiteAddress' => '123RANDOM ST,CHANTILLY,VA 20151',
        'CareSiteAddressCity' => 'MANASSAS',
        'CareSiteAddressStreeet' => '123 RANDOM STREET',
        'CareSiteAddressState' => 'VA',
        'CareSiteAddressZipCode' => '22030',
        'WorkHours' => nil,
        'ProviderGender' => 'NotSpecified',
        'ProviderNetwork' => 'Provider Agreement',
        'NetworkId' => 8,
        'ProviderAcceptingNewPatients' => false,
        'ProviderPrimaryCare' => false,
        'QualityRanking' => 0,
        'ProviderIdentifier' => '1700950045',
        'Latitude' => 45.5,
        'Longitude' => -122.5
      },
      {
        'Miles' => 59.2995756799325,
        'Minutes' => 60.97,
        'ProviderName' => 'DOCTOR PARTNERS OF SHENANDOAH VALLEY',
        'ProviderSpecialty' => 'Allergy & Immunology   ',
        'SpecialtyCode' => '207K00000X',
        'CareSite' => '1828 W PLAZA DR,WINCHESTER,VA,22601',
        'CareSiteAddress' => '1828 W PLAZA DR WINCHESTER,VA 22601',
        'CareSiteAddressCity' => 'MANASSAS',
        'CareSiteAddressStreet' => '123 RANDOM STREET',
        'CareSiteAddressState' => 'VA',
        'CareSiteAddressZipCode' => '22030',
        'CareSitePhoneNumber' => '(888) 444-1234',
        'WorkHours' => nil,
        'ProviderGender' => 'NotSpecified',
        'ProviderNetwork' => 'Provider Agreement',
        'NetworkId' => 8,
        'ProviderAcceptingNewPatients' => false,
        'ProviderPrimaryCare' => false,
        'QualityRanking' => 0,
        'ProviderIdentifier' => '1427435759',
        'Latitude' => 38.86787,
        'Longitude' => -78.17305
      },
      {
        'Miles' => 59.5528017001683,
        'Minutes' => 61.8516666666667,
        'ProviderName' => 'HEALTH CONSULTANTS OF VIRGINIA',
        'ProviderSpecialty' => 'Ophthalmology',
        'SpecialtyCode' => '207W00000X',
        'CareSite' => '420 W JUBAL EARLY DRIVE STE 203,WINCHESTER,VA,22601',
        'CareSiteAddress' => '420 W JUBAL EARLY DRIVE STE 203 WINCHESTER,VA 22601',
        'WorkHours' => nil,
        'ProviderGender' => 'NotSpecified',
        'ProviderNetwork' => 'Provider Agreement',
        'NetworkId' => 8,
        'ProviderAcceptingNewPatients' => false,
        'ProviderPrimaryCare' => false,
        'QualityRanking' => 0,
        'ProviderIdentifier' => '1114172319',
        'Latitude' => 39.16996,
        'Longitude' => -78.18052
      }
    ]
  end

  let(:response_body) { JSON.parse(YAML.load_file('spec/support/vcr_cassettes/facilities/va/ppms.yml')['http_interactions'][3]['response']['body']['string'])['value'][0] }
  let(:response) { Facilities::PPMS::Response.new(response_body, 200) }
  let(:bbox) { { bbox: [-79, 38, -77, 39] } }
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:provider_locator_response) { Facilities::PPMS::Response.from_provider_locator(faraday_response, bbox) }
  let(:mapped_provider_list) { Facilities::PPMS::Response.map_provider_list(provider_locator_body) }

  before do
    allow(faraday_response).to receive(:body) { provider_locator_body }
    allow(faraday_response).to receive(:status).and_return(200)
  end

  describe 'getting data' do
    context 'with a successful response' do
      it 'has the proper response object attributes' do
        expect(response).not_to be(nil)
        expect(response.body).to eq(response_body)
        expect(response.get_body).to eq(response_body)
        expect(response.status).to eq(200)
      end

      it 'has the proper provider locator response' do
        expect(provider_locator_response).not_to be(nil)
        expect(provider_locator_response.count).to eq(1)
        expect(provider_locator_response[0]['Name']).to eq('DOCTOR PARTNERS OF SHENANDOAH VALLEY')
      end

      it 'has the proper mapped provider list' do
        expect(mapped_provider_list).not_to be(nil)
        expect(mapped_provider_list.count).to eq(3)
      end
    end
  end
end
