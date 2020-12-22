# frozen_string_literal: true

require 'rails_helper'
require 'facilities/ppms/v1/client'

vcr_options = {
  cassette_name: 'facilities/ppms/ppms',
  match_requests_on: %i[path query],
  allow_playback_repeats: true,
  record: :new_episodes
}

RSpec.describe Facilities::PPMS::V1::Client, team: :facilities, vcr: vcr_options do
  let(:params) do
    {
      latitude: 40.415217,
      longitude: -74.057114,
      radius: 200
    }.with_indifferent_access
  end

  it 'is an PPMS::Client object' do
    expect(described_class.new).to be_an(Facilities::PPMS::V1::Client)
  end

  context 'with an http timeout' do
    it 'logs an error and raise GatewayTimeout' do
      allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
      expect do
        Facilities::PPMS::V1::Client.new.provider_locator(params.merge(specialties: ['213E00000X']))
      end.to raise_error(Common::Exceptions::GatewayTimeout)
    end
  end

  context 'with an unknown error from PPMS', vcr: {
    cassette_name: 'facilities/ppms/ppms_500',
    match_requests_on: %i[path]
  } do
    it 'raises BackendUnhandledException when errors happen' do
      expect { Facilities::PPMS::V1::Client.new.provider_locator(params.merge(specialties: ['213E00000X'])) }
        .to raise_error(Common::Exceptions::BackendServiceException) do |e|
          expect(e.message).to match(/PPMS_502/)
        end
    end
  end

  context 'Legacy Code, BBOX' do
    it 'Calculates the center and radius from bbox param' do
      bbox = ['-72.60', '41.86', '-75.5', '38.96']
      client = described_class.new

      # latitude: 40.415217
      # longitude: -74.057114
      # This method rounds to 2 decimal places and is not accurate enough

      expect(client.send(:center_and_radius, bbox)).to eql(
        latitude: 40.41,
        longitude: -74.05,
        radius: 200
      )
    end
  end

  describe '#provider_locator' do
    it 'returns a list of providers' do
      r = Facilities::PPMS::V1::Client.new.provider_locator(params.merge(specialties: ['213E00000X']))
      expect(r.length).to be 9
      expect(r[0]).to have_attributes(
        acc_new_patients: 'true',
        address_city: 'RED BANK',
        address_postal_code: '07701-1063',
        address_state_province: 'NJ',
        address_street: '176 RIVERSIDE AVE',
        care_site: 'VISITING NURSE ASSOCIATION OF CENTRAL J',
        caresite_phone: '732-219-6625',
        contact_method: nil,
        email: nil,
        fax: nil,
        gender: 'Female',
        latitude: 40.35396,
        longitude: -74.07492,
        main_phone: nil,
        miles: 5.477,
        provider_identifier: '1154383230',
        provider_name: 'GESUALDI, AMY',
        specialties: []
      )
    end
  end

  describe '#pos_locator' do
    it 'finds places of service' do
      r = Facilities::PPMS::V1::Client.new.pos_locator(params)
      expect(r.length).to be 10
      expect(r[0]).to have_attributes(
        acc_new_patients: 'false',
        address_city: 'BROOKLYN',
        address_postal_code: '11220-1909',
        address_state_province: 'NY',
        address_street: '5024 5TH AVE',
        care_site: 'CITY MD URGENT CARE',
        caresite_phone: '718-571-9251',
        contact_method: nil,
        email: nil,
        fax: nil,
        gender: 'NotSpecified',
        latitude: 40.644795,
        longitude: -74.011055,
        main_phone: nil,
        miles: 42.074,
        pos_codes: ['20'],
        provider_identifier: '1487993564',
        provider_name: 'CITY MD URGENT CARE',
        specialties: []
      )
    end
  end

  describe '#provider_info' do
    it 'gets additional attributes for the provider' do
      r = Facilities::PPMS::V1::Client.new.provider_info(1_154_383_230)
      expect(r).to have_attributes(
        acc_new_patients: 'true',
        address_city: 'ASBURY PARK',
        address_postal_code: nil,
        address_state_province: 'NJ',
        address_street: '1301 MAIN ST',
        care_site: nil,
        caresite_phone: nil,
        contact_method: nil,
        email: nil,
        fax: nil,
        gender: 'Female',
        latitude: nil,
        longitude: nil,
        main_phone: nil,
        miles: nil,
        provider_identifier: '1154383230',
        provider_name: nil
      )
      expect(r.specialties.each_with_object(Hash.new(0)) do |specialty, count|
        count[specialty.specialty_code] += 1
      end).to match('213E00000X' => 1)
    end
  end

  describe '#specialties', vcr: vcr_options.merge(cassette_name: 'facilities/ppms/ppms_specialties') do
    it 'returns some Specialties' do
      r = Facilities::PPMS::V1::Client.new.specialties
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
