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
    context 'when successful without show_proof_of_veteran_status_eligible flipper' do
      before do
        Flipper.disable(:profile_show_proof_of_veteran_status_eligible)
      end

      it 'returns a status of 200' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
          response = subject.get_service_history

          expect(response).to be_ok
          expect(response.episodes).to be_a(Array)
        end
      end

      it 'returns a single service history episode' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
          response = subject.get_service_history
          episode = response.episodes.first

          expect(episode.branch_of_service).to eq('Army')
        end
      end

      it 'returns multiple service history episodes' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200') do
          response = subject.get_service_history
          episodes = response.episodes

          expect(episodes.count).to eq(5)
          episodes.each do |e|
            expect(e.branch_of_service).not_to be_nil
            expect(e.begin_date).not_to be_nil
            expect(e.end_date).not_to be_nil
          end
        end
      end

      it 'sorts service history episodes' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200') do
          response = subject.get_service_history
          episodes = response.episodes

          expect(episodes.count).to eq(5)
          expect(episodes[0].begin_date).to eq('1999-06-23')
          expect(episodes[1].begin_date).to eq('2000-06-30')
          expect(episodes[2].begin_date).to eq('2002-02-02')
          expect(episodes[3].begin_date).to eq('2009-03-01')
          expect(episodes[4].begin_date).to eq('2012-03-02')
        end
      end

      it 'does not contain eligibility information' do
        VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes') do
          response = subject.get_service_history

          expect(response).to be_ok
          expect(response.vet_status_eligibility).to be_nil
        end
      end
    end

    context 'when successful with show_proof_of_veteran_status_eligible flipper' do
      before do
        Flipper.enable(:profile_show_proof_of_veteran_status_eligible)
      end

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
            'Our records show that you’re not eligible for a Veteran status card. To get a Veteran status card, you must have received an honorable discharge for at least one period of service.',
            'If you think your discharge status is incorrect, call the Defense Manpower Data Center at 800-538-9552 (TTY: 711). They’re open Monday through Friday, 8:00 a.m. to 8:00 p.m. ET.'
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
