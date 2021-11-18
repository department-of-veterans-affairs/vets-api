# frozen_string_literal: true

require 'rails_helper'
require 'facilities/ppms/v1/client'

vcr_options = {
  cassette_name: 'facilities/ppms/ppms_old',
  match_requests_on: %i[path query],
  allow_playback_repeats: true
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

  context 'StatsD notifications' do
    context 'PPMS responds Successfully' do
      it "sends a 'facilities.ppms.request.faraday' notification to any subscribers listening" do
        allow(StatsD).to receive(:measure)
        allow(StatsD).to receive(:increment)

        expect(StatsD).to receive(:measure).with(
          'facilities.ppms.provider_locator',
          kind_of(Numeric),
          hash_including(
            tags: [
              'facilities.ppms',
              'facilities.ppms.radius:200',
              'facilities.ppms.results:11'
            ]
          )
        )
        expect(StatsD).to receive(:increment).with(
          'facilities.ppms.response.total',
          hash_including(
            tags: [
              'http_status:200'
            ]
          )
        )

        expect do
          Facilities::PPMS::V1::Client.new.provider_locator(params.merge(specialties: ['213E00000X']))
        end.to instrument('facilities.ppms.request.faraday')
      end
    end

    context 'PPMS responds with a Failure', vcr: vcr_options.merge(
      cassette_name: 'facilities/ppms/ppms_500',
      match_requests_on: [:method]
    ) do
      it "sends a 'facilities.ppms.request.faraday' notification to any subscribers listening" do
        allow(StatsD).to receive(:measure)
        allow(StatsD).to receive(:increment)

        expect(StatsD).to receive(:measure).with(
          'facilities.ppms.provider_locator',
          kind_of(Numeric),
          hash_including(
            tags: [
              'facilities.ppms',
              'facilities.ppms.radius:200',
              'facilities.ppms.results:0'
            ]
          )
        )
        expect(StatsD).to receive(:increment).with(
          'facilities.ppms.response.total',
          hash_including(
            tags: [
              'http_status:500'
            ]
          )
        )
        expect(StatsD).to receive(:increment).with(
          'facilities.ppms.response.failures',
          hash_including(
            tags: [
              'http_status:500'
            ]
          )
        )

        expect do
          Facilities::PPMS::V1::Client.new.provider_locator(params.merge(specialties: ['213E00000X']))
        end.to raise_error(
          Common::Exceptions::BackendServiceException
        ).and instrument('facilities.ppms.request.faraday')
      end
    end
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
    match_requests_on: [:method]
  } do
    it 'raises BackendUnhandledException when errors happen' do
      expect { Facilities::PPMS::V1::Client.new.provider_locator(params.merge(specialties: ['213E00000X'])) }
        .to raise_error(Common::Exceptions::BackendServiceException) do |e|
          expect(e.message).to match(/PPMS_502/)
        end
    end
  end

  context 'with an empty result', vcr: vcr_options.merge(
    cassette_name: 'facilities/ppms/ppms_empty_search',
    match_requests_on: [:method]
  ) do
    it 'returns an empty array' do
      r = described_class.new.provider_locator(params.merge(specialties: ['213E00000X']))

      expect(r).to be_empty
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
      expect(r.length).to be 10
      expect(r[0]).to have_attributes(
        acc_new_patients: 'true',
        address_city: 'BELFORD',
        address_postal_code: '07718-1042',
        address_state_province: 'NJ',
        address_street: '55 LEONARDVILLE RD',
        care_site: 'ROBERT C LILLIE',
        caresite_phone: '732-787-4747',
        contact_method: nil,
        email: nil,
        fax: nil,
        gender: 'Male',
        latitude: 40.414248,
        longitude: -74.097581,
        main_phone: nil,
        miles: 2.5066,
        provider_identifier: '1437189941',
        provider_name: 'LILLIE, ROBERT C'
      )
    end
  end

  describe '#pos_locator' do
    it 'finds places of service' do
      r = Facilities::PPMS::V1::Client.new.pos_locator(params)
      expect(r.length).to be 10
      expect(r[0]).to have_attributes(
        acc_new_patients: 'false',
        address_city: 'ATLANTIC HIGHLANDS',
        address_postal_code: '07716',
        address_state_province: 'NJ',
        address_street: '2 BAYSHORE PLZ',
        care_site: 'BAYSHORE PHARMACY',
        caresite_phone: '732-291-2900',
        contact_method: nil,
        email: nil,
        fax: nil,
        gender: 'NotSpecified',
        latitude: 40.409114,
        longitude: -74.041849,
        main_phone: nil,
        miles: 1.019,
        pos_codes: %w[
          17
          20
        ],
        provider_identifier: '1225028293',
        provider_name: 'BAYSHORE PHARMACY'
      )
    end
  end

  describe '#provider_info' do
    it 'gets additional attributes for the provider' do
      r = Facilities::PPMS::V1::Client.new.provider_info(1_154_383_230)
      expect(r).to have_attributes(
        acc_new_patients: 'true',
        address_city: '1301 MAIN ST',
        address_postal_code: nil,
        address_state_province: 'NJ',
        address_street: 'ASBURY PARK',
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
