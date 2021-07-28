# frozen_string_literal: true

require 'rails_helper'

vcr_options = {
  cassette_name: 'facilities/ppms/ppms',
  match_requests_on: %i[path query],
  allow_playback_repeats: true,
  record: :new_episodes
}

RSpec.describe FacilitiesApi::V1::PPMS::Client, team: :facilities, vcr: vcr_options do
  let(:params) do
    {
      latitude: 40.415217,
      longitude: -74.057114,
      radius: 200
    }.with_indifferent_access
  end

  [false, true].each do |feature_flag|
    context "facility_locator_ppms_use_secure_api == #{feature_flag}" do
      before do
        Flipper.enable(:facility_locator_ppms_use_secure_api, feature_flag)
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
              FacilitiesApi::V1::PPMS::Client.new.provider_locator(params.merge(specialties: ['213E00000X']))
            end.to instrument('facilities.ppms.request.faraday')
          end
        end

        context 'PPMS responds with a Failure', vcr: vcr_options.merge(cassette_name: 'facilities/ppms/ppms_500') do
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
              FacilitiesApi::V1::PPMS::Client.new.provider_locator(params.merge(specialties: ['213E00000X']))
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
            FacilitiesApi::V1::PPMS::Client.new.provider_locator(params.merge(specialties: ['213E00000X']))
          end.to raise_error(Common::Exceptions::GatewayTimeout)
        end
      end

      context 'with an unknown error from PPMS', vcr: {
        cassette_name: 'facilities/ppms/ppms_500',
        match_requests_on: %i[path]
      } do
        it 'raises BackendUnhandledException when errors happen' do
          expect { FacilitiesApi::V1::PPMS::Client.new.provider_locator(params.merge(specialties: ['213E00000X'])) }
            .to raise_error(Common::Exceptions::BackendServiceException) do |e|
              expect(e.message).to match(/PPMS_502/)
            end
        end
      end

      context 'with an empty result', vcr: vcr_options.merge(cassette_name: 'facilities/ppms/ppms_empty_search') do
        it 'returns an empty array' do
          r = described_class.new.provider_locator(params.merge(specialties: ['213E00000X']))

          expect(r).to be_empty
        end
      end

      describe '#provider_locator' do
        describe 'Require between 1 and 5 Specialties' do
          let(:client) { FacilitiesApi::V1::PPMS::Client.new }
          let(:fake_response) { double('fake_response') }

          if feature_flag
            let(:path) { '/dws/v1.0/ProviderLocator' }
          else
            let(:path) { 'v1.0/ProviderLocator' }
          end

          it 'accepts upto 5 specialties' do
            allow(fake_response).to receive(:body)
            expect(client).to receive(:perform).with(
              :get,
              path,
              {
                address: '40.415217,-74.057114',
                maxResults: 11,
                radius: 200,
                specialtycode1: 'Code1',
                specialtycode2: 'Code2',
                specialtycode3: 'Code3',
                specialtycode4: 'Code4',
                specialtycode5: 'Code5'
              }
            ).and_return(fake_response)

            client.provider_locator(params.merge(specialties: %w[Code1 Code2 Code3 Code4 Code5]))
          end

          it 'ignores more than 5 specialties' do
            allow(fake_response).to receive(:body)
            expect(client).to receive(:perform).with(
              :get,
              path,
              {
                address: '40.415217,-74.057114',
                maxResults: 11,
                radius: 200,
                specialtycode1: 'Code1',
                specialtycode2: 'Code2',
                specialtycode3: 'Code3',
                specialtycode4: 'Code4',
                specialtycode5: 'Code5'
              }
            ).and_return(fake_response)

            client.provider_locator(params.merge(specialties: %w[Code1 Code2 Code3 Code4 Code5 Code6]))
          end
        end

        it 'returns a list of providers' do
          r = FacilitiesApi::V1::PPMS::Client.new.provider_locator(params.merge(specialties: ['213E00000X']))
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
            miles: 2.5153,
            provider_identifier: '1437189941',
            provider_name: 'LILLIE, ROBERT C'
          )
        end
      end

      describe '#pos_locator' do
        it 'finds places of service' do
          r = FacilitiesApi::V1::PPMS::Client.new.pos_locator(params)
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
            miles: 1.0277,
            pos_codes: %w[
              17
              20
            ],
            provider_identifier: '1225028293',
            provider_name: 'BAYSHORE PHARMACY'
          )
        end
      end

      describe '#specialties', vcr: vcr_options.merge(cassette_name: 'facilities/ppms/ppms_specialties') do
        it 'returns some Specialties' do
          r = FacilitiesApi::V1::PPMS::Client.new.specialties
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
end
