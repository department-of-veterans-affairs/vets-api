# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/disability/service'

describe VAProfile::Disability::Service do
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

  describe '#get_disability_data' do
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('va_profile/disability/disability_rating_200_high_disability') do
          response = subject.get_disability_data

          expect(response).to be_ok
          expect(response.disability_rating).to be_a(VAProfile::Models::Disability)
        end
      end

      it 'returns a disability rating percentage' do
        VCR.use_cassette('va_profile/disability/disability_rating_200_high_disability') do
          response = subject.get_disability_data

          expect(response.disability_rating.combined_service_connected_rating_percentage).to eq('60')
        end
      end
    end

    context 'when unsuccessful' do
      it 'returns nil disability rating for 404' do
        VCR.use_cassette('va_profile/disability/disability_rating_404') do
          response = subject.get_disability_data

          expect(response).not_to be_ok
          expect(response.disability_rating).to eq(nil)
        end
      end

      it 'logs exception to sentry' do
        VCR.use_cassette('va_profile/disability/disability_rating_404') do
          expect_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry).with(
            instance_of(Common::Client::Errors::ClientError),
            { edipi: user.edipi },
            { va_profile: :disability_rating_not_found },
            :warning
          )
          subject.get_disability_data
        end
      end

      it 'returns nil disability rating for 400' do
        VCR.use_cassette('va_profile/disability/disability_rating_400') do
          response = subject.get_disability_data

          expect(response).not_to be_ok
          expect(response.disability_rating).to eq(nil)
        end
      end

      it 'raises error for 500' do
        VCR.use_cassette('va_profile/disability/disability_rating_500') do
          expect { subject.get_disability_data }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end
