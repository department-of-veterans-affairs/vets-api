# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/veteran_status'
require 'va_profile_redis/veteran_status'

RSpec.describe VAProfileRedis::VeteranStatus, type: :model do
  subject { described_class.for_user(user) }

  let(:user) { build(:user, :loa3) }

  describe '.for_user' do
    it 'returns an instance of VeteranStatus with the user set' do
      VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: %i[body]) do
        expect(subject.user).to eq(user)
      end
    end
  end

  describe '#title38_status' do
    context 'when user is loa3' do
      it 'returns title38_status value' do
        VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: %i[body]) do
          expect(subject.title38_status).to be_present
        end
      end
    end

    context 'when user is not loa3' do
      let(:user) { build(:user, :loa1) }
      let(:edipi) { '1005127153' }

      before do
        allow(user).to receive(:edipi).and_return(edipi)
      end

      it 'returns nil' do
        VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: %i[body]) do
          expect(subject.title38_status).to be_nil
        end
      end
    end
  end

  describe '#status' do
    context 'when user is loa3' do
      it 'returns status from the response' do
        VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: %i[body]) do
          expect(subject.status).to be_present
        end
      end
    end

    context 'when user is not loa3' do
      let(:user) { build(:user, :loa1) }
      let(:edipi) { '1005127153' }

      before do
        allow(user).to receive(:edipi).and_return(edipi)
      end

      it 'returns not authorized' do
        VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: %i[method]) do
          expect(subject.status).to eq(VAProfile::Response::RESPONSE_STATUS[:not_authorized])
        end
      end
    end
  end

  describe '#response' do
    it 'returns a response either from redis or service' do
      VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: %i[body]) do
        expect(subject.response).to be_present
      end
    end
  end

  describe 'private methods' do
    describe '#value_for' do
      it 'returns value for the given key from the veteran status response' do
        VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: %i[body]) do
          expect(subject.send(:value_for, 'title38_status_code')).to be_present
        end
      end
    end

    describe '#response_from_redis_or_service' do
      context 'when cache is disabled' do
        before do
          allow(VAProfile::Configuration::SETTINGS.veteran_status).to receive(:cache_enabled).and_return(false)
        end

        it 'fetches response from the service' do
          VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: %i[body],
                                                                                      allow_playback_repeats: true) do
            expect(subject.send(:response_from_redis_or_service)).to be_present
          end
        end
      end

      context 'when cache is enabled' do
        before do
          allow(VAProfile::Configuration::SETTINGS.veteran_status).to receive(:cache_enabled).and_return(true)
        end

        it 'fetches response from cache or service' do
          VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: %i[body]) do
            expect(subject.send(:response_from_redis_or_service)).to be_present
          end
        end
      end
    end
  end
end
