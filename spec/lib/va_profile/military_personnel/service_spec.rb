# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/military_personnel/service'

describe VAProfile::MilitaryPersonnel::Service do
  subject { described_class.new(user) }

  let(:user) { build(:user, :loa3) }
  let(:edipi) { '384759483' }

  before do
    allow(user).to receive(:edipi).and_return(edipi)
  end

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

          expect(episodes.count).to eq(2)
          episodes.each do |e|
            expect(e.branch_of_service).not_to be_nil
            expect(e.begin_date).not_to be_nil
            expect(e.end_date).not_to be_nil
            expect(e.personnel_category_type_code).not_to be_nil
          end
        end
      end
    end

    context 'when not successful' do
      context 'with a 400 error' do
        it 'returns nil service history' do
          VCR.use_cassette('va_profile/military_personnel/post_read_service_history_400') do
            response = subject.get_service_history

            expect(response).not_to be_ok
            expect(response.episodes.count).to eq(0)
          end
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
