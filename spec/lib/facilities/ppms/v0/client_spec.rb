# frozen_string_literal: true

require 'rails_helper'
require 'facilities/ppms/v0/client'

RSpec.describe Facilities::PPMS::V0::Client, team: :facilities do
  let(:params) do
    {
      address: 'South Gilbert Road, Chandler, Arizona 85286, United States',
      bbox: [-112.54, 32.53, -111.04, 34.03]
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
          AddressCity: 'Chandler',
          AddressPostalCode: '85286',
          AddressStateProvince: 'AZ',
          AddressStreet: '1831 E Queen Creek Rd Ste 119',
          CareSite: 'Foot & Ankle Clinics of Arizona',
          CareSitePhoneNumber: '4809172300',
          ContactMethod: nil,
          Email: nil,
          IsAcceptingNewPatients: 'true',
          Latitude: 33.262403,
          Longitude: -111.808538,
          MainPhone: nil,
          Miles: 1.679,
          OrganizationFax: nil,
          ProviderGender: 'Male',
          ProviderIdentifier: '1386050060',
          ProviderName: 'OBryant, Steven',
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
          ProviderIdentifier: '1609229764',
          ProviderHexdigest: '398681135712746c43545dad381cacaba234e249f02459246ae709a6200f6c41',
          CareSite: 'Banner Urgent Care Services LLC',
          AddressStreet: '3200 S Gilbert Rd',
          AddressCity: 'Chandler',
          AddressStateProvince: 'AZ',
          AddressPostalCode: '85286',
          Email: nil,
          MainPhone: nil,
          CareSitePhoneNumber: '4808275700',
          OrganizationFax: nil,
          ContactMethod: nil,
          IsAcceptingNewPatients: 'true',
          ProviderGender: 'NotSpecified',
          ProviderSpecialties: [],
          Latitude: 33.259952,
          Longitude: -111.790163,
          Miles: 0.744,
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
