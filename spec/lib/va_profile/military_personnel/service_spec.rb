# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/military_personnel/service'

describe VAProfile::MilitaryPersonnel::Service do
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

  describe '#get_service_history' do
    context 'when successful' do
      it 'contains eligibility information' do
        VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes') do
          response = subject.get_service_history

          expect(response).to be_ok
          expect(response.vet_status_eligibility).to be_a(Object)
        end
      end

      it 'eligibility information contains confirmed and message attributes' do
        VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes') do
          response = subject.get_service_history

          expect(response.vet_status_eligibility[:confirmed]).to eq(true)
          expect(response.vet_status_eligibility[:message]).to eq([])
        end
      end

      it 'returns not eligible if character_of_discharge_codes are missing' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200') do
          response = subject.get_service_history
          message = [
            'Our records show that you’re not eligible for a Veteran status card. To get a Veteran status card, you ' \
            'must have received an honorable discharge for at least one period of service.',
            'If you think your discharge status is incorrect, call the Defense Manpower Data Center at 800-538-9552 ' \
            '(TTY: 711). They’re open Monday through Friday, 8:00 a.m. to 8:00 p.m. ET.'
          ]

          expect(response.vet_status_eligibility[:confirmed]).to eq(false)
          expect(response.vet_status_eligibility[:message]).to eq(message)
        end
      end
    end

    context 'when not successful' do
      it 'returns nil service history' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_400') do
          response = subject.get_service_history

          expect(response).not_to be_ok
          expect(response.episodes.count).to eq(0)
          expect(response.vet_status_eligibility).to be_nil
        end
      end

      it 'logs exception to sentry' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_404') do
          expect_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry).with(
            instance_of(Common::Client::Errors::ClientError),
            { edipi: '384759483' },
            { va_profile: :service_history_not_found },
            :warning
          )

          response = subject.get_service_history

          expect(response).not_to be_ok
          expect(response.episodes.count).to eq(0)
        end
      end
    end

    context 'when service returns a 500 error code' do
      it 'raises a BackendServiceException error' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_500') do
          expect { subject.get_service_history }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(400)
            expect(e.errors.first.code).to eq('VET360_CORE100')
          end
        end
      end
    end
  end
end
