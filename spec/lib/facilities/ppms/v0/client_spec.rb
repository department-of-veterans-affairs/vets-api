# frozen_string_literal: true

require 'rails_helper'
require 'facilities/ppms/v0/client'

RSpec.describe Facilities::PPMS::V0::Client, team: :facilities do
  let(:params) do
    {
      address: '58 Leonard Ave, Leonardo, NJ 07737',
      bbox: [-75.91, 38.55, -72.19, 42.27]
    }.with_indifferent_access
  end

  it 'is an PPMS::Client object' do
    expect(described_class.new).to be_an(Facilities::PPMS::V0::Client)
  end

  context 'with an http timeout' do
    it 'logs an error and raise GatewayTimeout' do
      allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
      expect do
        Facilities::PPMS::V0::Client.new.provider_locator(params)
      end.to raise_error(Common::Exceptions::GatewayTimeout)
    end
  end

  context 'with an unknown error from PPMS' do
    it 'raises BackendUnhandledException when errors happen' do
      VCR.use_cassette('facilities/ppms/ppms_500', match_requests_on: %i[path]) do
        expect { Facilities::PPMS::V0::Client.new.provider_locator(params) }
          .to raise_error(Common::Exceptions::BackendServiceException) do |e|
            expect(e.message).to match(/PPMS_502/)
          end
      end
    end
  end

  describe '#provider_locator' do
    it 'returns a list of providers' do
      VCR.use_cassette('facilities/ppms/ppms', match_requests_on: %i[path query]) do
        r = Facilities::PPMS::V0::Client.new.provider_locator(params.merge(services: ['213E00000X']))
        expect(r.length).to be 10
        expect(r[0]).to have_attributes(
          AddressCity: 'RED BANK',
          AddressPostalCode: '07701-1063',
          AddressStateProvince: 'NJ',
          AddressStreet: '176 RIVERSIDE AVE',
          CareSite: 'VISITING NURSE ASSOCIATION OF CENTRAL J',
          CareSitePhoneNumber: '732-219-6625',
          ContactMethod: nil,
          Email: nil,
          IsAcceptingNewPatients: 'true',
          Latitude: 40.35396,
          Longitude: -74.07492,
          MainPhone: nil,
          Miles: 5.474,
          OrganizationFax: nil,
          ProviderGender: 'Female',
          ProviderIdentifier: '1154383230',
          ProviderName: 'GESUALDI, AMY',
          ProviderSpecialties: []
        )
      end
    end
  end

  describe '#pos_locator' do
    it 'finds places of service' do
      VCR.use_cassette('facilities/ppms/ppms', match_requests_on: %i[path query]) do
        r = Facilities::PPMS::V0::Client.new.pos_locator(params)
        expect(r.length).to be 10
        expect(r[0]).to have_attributes(
          ProviderIdentifier: '1487993564',
          ProviderHexdigest: '263e81aab50e1c4ea77e84ff7130473f074036f0f01e86abe5ad4a1864c77cb9',
          CareSite: 'CITY MD URGENT CARE',
          AddressStreet: '5024 5TH AVE',
          AddressCity: 'BROOKLYN',
          AddressStateProvince: 'NY',
          AddressPostalCode: '11220-1909',
          Email: nil,
          MainPhone: nil,
          CareSitePhoneNumber: '718-571-9251',
          OrganizationFax: nil,
          ContactMethod: nil,
          IsAcceptingNewPatients: 'false',
          ProviderGender: 'NotSpecified',
          ProviderSpecialties: [],
          Latitude: 40.644795,
          Longitude: -74.011055,
          Miles: 42.071,
          posCodes: '20'
        )
      end
    end
  end

  describe '#provider_info' do
    it 'gets additional attributes for the provider' do
      VCR.use_cassette('facilities/ppms/ppms', match_requests_on: %i[path query]) do
        r = Facilities::PPMS::V0::Client.new.provider_info(1_154_383_230)
        expect(r).to have_attributes(
          AddressCity: 'ASBURY PARK',
          AddressPostalCode: nil,
          AddressStateProvince: 'NJ',
          AddressStreet: '1301 MAIN ST',
          CareSite: nil,
          CareSitePhoneNumber: nil,
          ContactMethod: nil,
          Email: nil,
          IsAcceptingNewPatients: 'true',
          Latitude: nil,
          Longitude: nil,
          MainPhone: nil,
          Miles: nil,
          OrganizationFax: nil,
          ProviderGender: 'Female',
          ProviderIdentifier: '1154383230',
          ProviderName: nil
        )
        expect(r['ProviderSpecialties'].each_with_object(Hash.new(0)) do |specialty, count|
          count[specialty['CodedSpecialty']] += 1
        end).to match('213E00000X' => 1)
      end
    end
  end

  describe '#provider_services' do
    it 'returns Services' do
      VCR.use_cassette('facilities/ppms/ppms', match_requests_on: %i[path query]) do
        r = Facilities::PPMS::V0::Client.new.provider_services(1_154_383_230)

        name_hash = { 'GESUALDI, AMY - Podiatrist' => 4 }

        expect(r.each_with_object(Hash.new { |h, k| h[k] = Hash.new(0) }) do |service, count|
          %w[Name AffiliationName RelationshipName CareSiteName CareSiteAddressZipCode].each do |key|
            count[key][service[key]] += 1
          end
        end).to match(
          'Name' => name_hash,
          'AffiliationName' => {
            'CCN Region 1' => 4
          },
          'RelationshipName' => {
            'CCN' => 4
          },
          'CareSiteName' => {
            'VISITING NURSE ASSOCIATION OF CENTRAL' => 1,
            'VISITING NURSE ASSOCIATION OF CENTRAL J' => 3
          },
          'CareSiteAddressZipCode' => {
            '07712-5359' => 1,
            '07701-2162' => 1,
            '07701-1063' => 1,
            '07735-1267' => 1
          }
        )
      end
    end
  end

  describe '#specialties' do
    it 'returns some Specialties' do
      VCR.use_cassette('facilities/ppms/ppms_specialties', match_requests_on: %i[path query]) do
        r = Facilities::PPMS::V0::Client.new.specialties
        expect(r.each_with_object(Hash.new(0)) do |specialty, count|
          count[specialty['SpecialtyCode']] += 1
        end).to match(
          '101Y00000X' => 1,
          '101YA0400X' => 1,
          '101YM0800X' => 1,
          '101YP1600X' => 1,
          '101YP2500X' => 1,
          '101YS0200X' => 1
        )
      end
    end
  end
end
