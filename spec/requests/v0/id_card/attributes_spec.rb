# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::IdCard::Attributes', type: :request do
  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:current_user) { build(:user, :loa3) }

  before do
    allow(Settings.vic).to receive(:signing_key_path)
      .and_return(Rails.root.join(*'/spec/support/certificates/vic-signing-key.pem'.split('/')).to_s)

    sign_in_as(current_user)
  end

  describe '#show /v0/id_card/attributes' do
    context 'VAProfile and Military Information' do
      let(:service_episodes) { [build(:prefill_service_episode)] }

      it 'returns a signed redirect URL' do
        VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: [:method],
                                                                                    allow_playback_repeats: true) do
          allow(VAProfile::Configuration::SETTINGS.veteran_status).to receive(:cache_enabled).and_return(true)
          expect_any_instance_of(
            VAProfileRedis::VeteranStatus
          ).to receive(:title38_status).at_least(:once).and_return('V1')
          get '/v0/id_card/attributes', headers: auth_header
          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          url = json['url']
          expect(url).to be_truthy
          traits = json['traits']
          expect(traits).to be_key('edipi')
          expect(traits).to be_key('firstname')
          expect(traits).to be_key('lastname')
          expect(traits).to be_key('title38status')
          expect(traits).to be_key('branchofservice')
          expect(traits).to be_key('dischargetype')
          expect(traits).to be_key('timestamp')
          expect(traits).to be_key('signature')
        end
      end

      it 'returns VA Profile discharge codes for all service episodes' do
        VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: [:method],
                                                                                    allow_playback_repeats: true) do
          VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes',
                           allow_playback_repeats: true) do
            allow(VAProfile::Configuration::SETTINGS.veteran_status).to receive(:cache_enabled).and_return(true)
            expect_any_instance_of(
              VAProfileRedis::VeteranStatus
            ).to receive(:title38_status).at_least(:once).and_return('V1')
            get '/v0/id_card/attributes', headers: auth_header
            expect(response).to have_http_status(:ok)
            json = JSON.parse(response.body)
            url = json['url']
            expect(url).to be_truthy
            traits = json['traits']
            expect(traits['dischargetype']).to eq('B')
          end
        end
      end

      it 'returns an empty string from VA Profile if no discharge type' do
        VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: [:method],
                                                                                    allow_playback_repeats: true) do
          VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200') do
            allow(VAProfile::Configuration::SETTINGS.veteran_status).to receive(:cache_enabled).and_return(true)
            expect_any_instance_of(
              VAProfileRedis::VeteranStatus
            ).to receive(:title38_status).at_least(:once).and_return('V1')
            get '/v0/id_card/attributes', headers: auth_header
            expect(response).to have_http_status(:ok)
            json = JSON.parse(response.body)
            url = json['url']
            expect(url).to be_truthy
            traits = json['traits']
            expect(traits['dischargetype']).to eq('')
          end
        end
      end

      it 'returns VA Profile discharge codes for single service episode' do
        VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: [:method],
                                                                                    allow_playback_repeats: true) do
          VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200',
                           allow_playback_repeats: true) do
            allow(VAProfile::Configuration::SETTINGS.veteran_status).to receive(:cache_enabled).and_return(true)
            expect_any_instance_of(
              VAProfileRedis::VeteranStatus
            ).to receive(:title38_status).at_least(:once).and_return('V1')
            get '/v0/id_card/attributes', headers: auth_header
            expect(response).to have_http_status(:ok)
            json = JSON.parse(response.body)
            url = json['url']
            expect(url).to be_truthy
            traits = json['traits']
            expect(traits['dischargetype']).to eq('B')
          end
        end
      end

      it 'returns Bad Gateway if military information not retrievable' do
        VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: [:method],
                                                                                    allow_playback_repeats: true) do
          allow(VAProfile::Configuration::SETTINGS.veteran_status).to receive(:cache_enabled).and_return(true)
          expect_any_instance_of(
            VAProfileRedis::VeteranStatus
          ).to receive(:title38_status).at_least(:once).and_return('V1')
          expect_any_instance_of(VAProfile::Prefill::MilitaryInformation)
            .to receive(:service_episodes_by_date).and_raise(StandardError)
          get '/v0/id_card/attributes', headers: auth_header
          expect(response).to have_http_status(:bad_gateway)
        end
      end
    end

    it 'returns VIC002 if title38status is not retrievable' do
      VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: [:method],
                                                                                  allow_playback_repeats: true) do
        allow(VAProfile::Configuration::SETTINGS.veteran_status).to receive(:cache_enabled).and_return(true)
        expect_any_instance_of(
          VAProfileRedis::VeteranStatus
        ).to receive(:title38_status).and_return(nil)
        get '/v0/id_card/attributes', headers: auth_header
        expect(JSON.parse(response.body)['errors'][0]['code']).to eq(
          'VIC002'
        )
      end
    end

    it 'returns Forbidden for non-veteran user' do
      VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: [:method],
                                                                                  allow_playback_repeats: true) do
        allow(VAProfile::Configuration::SETTINGS.veteran_status).to receive(:cache_enabled).and_return(true)
        expect_any_instance_of(
          VAProfileRedis::VeteranStatus
        ).to receive(:title38_status).at_least(:once).and_return('V2')
        get '/v0/id_card/attributes', headers: auth_header
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'][0]['code']).to eq(
          'VICV2'
        )
      end
    end

    it 'returns Forbidden when veteran status not retrievable' do
      VCR.use_cassette('va_profile/veteran_status/veteran_status_400', match_requests_on: [:method],
                                                                       allow_playback_repeats: true) do
        allow(VAProfile::Configuration::SETTINGS.veteran_status).to receive(:cache_enabled).and_return(true)
        allow_any_instance_of(VAProfileRedis::VeteranStatus)
          .to receive(:title38_status).and_raise(StandardError)
        get '/v0/id_card/attributes', headers: auth_header
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
