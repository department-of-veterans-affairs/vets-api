# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/veteran_status/service'

describe VAProfile::VeteranStatus::Service, if: Flipper.enabled?(:veteran_status_updated) do
  subject { described_class.new(user) }

  let(:user) { build(:user, :loa3) }

  describe '#identity_path' do
    context 'when an edipi exists' do
      it 'returns a valid identity path' do
        path = subject.identity_path
        expect(path).to eq('2.16.840.1.113883.3.42.10001.100001.12/384759483%5ENI%5E200DOD%5EUSDOD')
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
        VCR.use_cassette('va_profile/veteran_status/veteran_status_400_', match_requests_on: [:method]) do
          expect_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry).with(
            instance_of(Common::Client::Errors::ClientError),
            { edipi: '384759483' },
            { va_profile: :client_error_related_to_title38 },
            :warning
          )
          expect { subject.get_veteran_status }.to raise_error(VAProfile::VeteranStatus::VAProfileError)
        end
      end

      it 'gives me a 404 response' do
        VCR.use_cassette('va_profile/veteran_status/veteran_status_404_oid_blank', match_requests_on: [:method]) do
          expect_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry).with(
            instance_of(Common::Client::Errors::ClientError),
            { edipi: '384759483' },
            { va_profile: :veteran_status_title_not_found },
            :warning
          )

          expect { subject.get_veteran_status }.to raise_error(VAProfile::VeteranStatus::VAProfileError)
        end
      end

      it 'gives me a 500 response' do
        VCR.use_cassette('va_profile/veteran_status/veteran_status_500_aaid', match_requests_on: [:method]) do
          expect do
            subject.get_veteran_status
          end.to raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end
  end
end
