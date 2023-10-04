# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/veteran_status/service'

describe VAProfile::VeteranStatus::Service, if: Flipper.enabled?(:veteran_status_updated) do

  let(:user) { build(:user, :loa3) }
  let(:edipi) { '1005127153' }
  subject { described_class.new(user) }

  before do
    allow(user).to receive(:edipi).and_return(edipi)
  end

  describe '#identity_path' do
    context 'when an edipi exists' do
      it 'returns a valid identity path' do
        path = subject.identity_path
        expect(path).to eq('2.16.840.1.113883.3.42.10001.100001.12/1005127153%5ENI%5E200DOD%5EUSDOD')
      end
    end
  end

  describe 'get_veteran_status' do
    context 'with a valid request' do
      it 'calls the get_veteran_status endpoint with a proper emis message' do
        VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: [:method]) do
          response = subject.get_veteran_status
          expect(response).to be_ok
        end
      end

      it 'gives me the right values back' do
        VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: [:method]) do
          response = subject.get_veteran_status
          expect(response.title38_status_code.title38_status_code).to eq('V1')
        end
      end
    end

    context 'throws an error' do
      it 'gives me a 400 response' do
        VCR.use_cassette('va_profile/veteran_status/veteran_status_400_') do
<<<<<<< HEAD

=======
>>>>>>> 751d843c0f5d093510bf2d20b1ba9db12b1a08c0
          expect_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry).with(
            instance_of(Common::Client::Errors::ClientError),
            { edipi: '384759483' },
            { va_profile: :client_error_related_to_title38 },
            :warning
          )
          response = subject.get_veteran_status
<<<<<<< HEAD

          expect(response).not_to be_ok
          expect(response.status).to eq(400)
          expect(response.title38_status_code).to eq(nil)
=======
          expect(response).not_to be_ok
          expect(response.status).to eq(400)
          expect(response.title38_status_code).to eq(nil)
          expect(response).to raise_error(VAProfile::VeteranStatus::VAProfileError)
>>>>>>> 751d843c0f5d093510bf2d20b1ba9db12b1a08c0
        end
      end

      it 'gives me a 404 response' do
        VCR.use_cassette('va_profile/veteran_status/veteran_status_404_oid_blank') do
          expect_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry).with(
            instance_of(Common::Client::Errors::ClientError),
            { edipi: '384759483' },
            { va_profile: :veteran_status_title_not_found },
            :warning
          )

          response = subject.get_veteran_status
          expect(response).not_to be_ok
          expect(response.status).to eq(404)
          expect(response.title38_status_code).to eq(nil)
<<<<<<< HEAD
=======
          expect(response).to raise_error(VAProfile::VeteranStatus::VAProfileError)
>>>>>>> 751d843c0f5d093510bf2d20b1ba9db12b1a08c0
        end
      end

      it 'gives me a 500 response' do
        VCR.use_cassette('va_profile/veteran_status/veteran_status_500_aaid') do
          response = subject.get_veteran_status
          expect(response).not_to be_ok
          expect(response.status).to eq(500)
          expect(response.title38_status_code).to eq(nil)
          expect(response).to raise_error(VAProfile::VeteranStatus::VAProfileError)
        end
      end
    end
  end
end
