# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Facilities::PPMS::Client do
  let(:params) do
    {
      address: 'South Gilbert Road, Chandler, Arizona 85286, United States',
      bbox: [-112.54, 32.53, -111.04, 34.03]
    }.with_indifferent_access
  end

  it 'is an PPMS::Client object' do
    expect(described_class.new).to be_an(Facilities::PPMS::Client)
  end

  context 'with an http timeout' do
    it 'logs an error and raise GatewayTimeout' do
      allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
      expect do
        Facilities::PPMS::Client.new.provider_locator(params)
      end.to raise_error(Common::Exceptions::GatewayTimeout)
    end
  end

  context 'with an unknown error from PPMS' do
    it 'raises BackendUnhandledException when errors happen' do
      VCR.use_cassette('facilities/va/ppms_500', match_requests_on: %i[path]) do
        expect { Facilities::PPMS::Client.new.provider_locator(params) }
          .to raise_error(Common::Exceptions::BackendServiceException) do |e|
            expect(e.message).to match(/PPMS_502/)
          end
      end
    end
  end

  describe '#provider_locator' do
    it 'returns a list of providers' do
      VCR.use_cassette('facilities/va/ppms', match_requests_on: %i[path query]) do
        r = Facilities::PPMS::Client.new.provider_locator(params.merge(services: ['213E00000X']))
        expect(r.length).to be 5
        expect(r[0]).to have_attributes(
          AddressCity: 'Chandler',
          AddressPostalCode: '85248',
          AddressStateProvince: 'AZ',
          AddressStreet: '3195 S Price Rd Ste 148',
          CareSitePhoneNumber: '4807057300',
          ContactMethod: nil,
          Email: nil,
          IsAcceptingNewPatients: 'true',
          Latitude: 33.258135,
          Longitude: -111.887927,
          MainPhone: nil,
          Miles: 2.302,
          Name: 'Freed, Lewis ',
          OrganizationFax: nil,
          ProviderGender: 'Male',
          ProviderIdentifier: '1407842941',
          ProviderSpecialties: []
        )
      end
    end
  end

  describe '#pos_locator' do
    it 'finds places of service' do
      VCR.use_cassette('facilities/va/ppms', match_requests_on: %i[path query]) do
        r = Facilities::PPMS::Client.new.pos_locator(params, '17')
        expect(r.length).to be 5
        expect(r[0]).to have_attributes(
          ProviderIdentifier: '1629245311',
          Name: 'MinuteClinic LLC',
          AddressStreet: '2010 S Dobson Rd',
          AddressCity: 'Chandler',
          AddressStateProvince: 'AZ',
          AddressPostalCode: '85286',
          Email: nil,
          MainPhone: nil,
          CareSitePhoneNumber: '8663892727',
          OrganizationFax: nil,
          ContactMethod: nil,
          IsAcceptingNewPatients: 'false',
          ProviderGender: 'NotSpecified',
          ProviderSpecialties: [],
          Latitude: 33.275526,
          Longitude: -111.877057,
          Miles: 0.79
        )
      end
    end
  end

  describe '#provider_info' do
    it 'gets additional attributes for the provider' do
      VCR.use_cassette('facilities/va/ppms', match_requests_on: %i[path query]) do
        r = Facilities::PPMS::Client.new.provider_info(1_407_842_941)
        expect(r).to have_attributes(
          AddressCity: nil,
          AddressPostalCode: nil,
          AddressStateProvince: nil,
          AddressStreet: nil,
          CareSitePhoneNumber: nil,
          ContactMethod: nil,
          Email: 'evfa1@hotmail.com',
          IsAcceptingNewPatients: 'true',
          Latitude: nil,
          Longitude: nil,
          MainPhone: '4809241552',
          Miles: nil,
          Name: 'Freed, Lewis ',
          OrganizationFax: '4809241553',
          ProviderGender: 'Male',
          ProviderIdentifier: '1407842941'
        )
        expect(r['ProviderSpecialties'].each_with_object(Hash.new(0)) do |specialty, count|
          count[specialty['CodedSpecialty']] += 1
        end).to match('213E00000X' => 41)
      end
    end
  end

  describe '#provider_services' do
    it 'returns Services' do
      VCR.use_cassette('facilities/va/ppms', match_requests_on: %i[path query]) do
        r = Facilities::PPMS::Client.new.provider_services(1_407_842_941)
        expect(r.each_with_object(Hash.new { |h, k| h[k] = Hash.new(0) }) do |service, count|
          %w[Name AffiliationName RelationshipName CareSiteName CareSiteAddressZipCode].each do |key|
            count[key][service[key]] += 1
          end
        end).to match(
          'Name' => {
            'Freed, Lewis - Podiatrist ' => 25,
            'Freed, Lewis  - Podiatrist    ' => 2,
            'Freed, Lewis  - Podiatrist ' => 12,
            'Freed, Lewis - Podiatrist    ' => 2
          },
          'AffiliationName' => {
            'TriWest - PC3' => 25,
            'TriWest - Choice' => 16
          },
          'RelationshipName' => {
            'PC3' => 25,
            'Choice' => 16
          },
          'CareSiteName' => {
            'Orthopedic Specialists of North America PLLC' => 19,
            'Lewis H Freed DPM PC' => 16,
            'OrthoArizona' => 4,
            'OSNA PLLC' => 2
          },
          'CareSiteAddressZipCode' => {
            '85206' => 14,
            '85248' => 8,
            '85226' => 7,
            '85258' => 4,
            '85295' => 7,
            '85234' => 1
          }
        )
      end
    end
  end

  describe '#specialties' do
    it 'returns some Specialties' do
      VCR.use_cassette('facilities/va/ppms', match_requests_on: %i[path query]) do
        r = Facilities::PPMS::Client.new.specialties
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
