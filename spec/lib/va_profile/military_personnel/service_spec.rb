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

          expect(response.vet_status_eligibility[:confirmed]).to be(true)
          expect(response.vet_status_eligibility[:message]).to eq([])
        end
      end

      it 'returns not eligible if character_of_discharge_codes are missing' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200') do
          response = subject.get_service_history

          expect(response.vet_status_eligibility[:confirmed]).to be(false)
          expect(response.vet_status_eligibility[:message]).to eq(
            VeteranVerification::Constants::NOT_ELIGIBLE_MESSAGE
          )
          expect(response.vet_status_eligibility[:title]).to eq(
            VeteranVerification::Constants::NOT_ELIGIBLE_MESSAGE_TITLE
          )
          expect(response.vet_status_eligibility[:status]).to eq(
            VeteranVerification::Constants::NOT_ELIGIBLE_MESSAGE_STATUS
          )
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
          expect_any_instance_of(Vets::SharedLogging).to receive(:log_exception_to_sentry).with(
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

  describe '#get_dod_service_summary' do
    context 'when successful' do
      it 'returns a dod service summary' do
        VCR.use_cassette('va_profile/military_personnel/dod_service_summary_200') do
          response = subject.get_dod_service_summary

          expect(response).to be_ok
          expect(response.dod_service_summary).to be_a(VAProfile::Models::DodServiceSummary)
          expect(response.dod_service_summary.dod_service_summary_code).to eq('V')
          expect(response.dod_service_summary.calculation_model_version).to eq('1.0')
          expect(response.dod_service_summary.effective_start_date).to eq('2020-01-01')
        end
      end
    end

    context 'when not successful' do
      it 'returns nil dod service summary with 400' do
        VCR.use_cassette('va_profile/military_personnel/dod_service_summary_400') do
          response = subject.get_dod_service_summary

          expect(response).not_to be_ok
          expect(response.dod_service_summary).to be_nil
        end
      end

      it 'logs warning with 404' do
        VCR.use_cassette('va_profile/military_personnel/dod_service_summary_404') do
          expect(Rails.logger).to receive(:warn).with('Dod Service Summary not found', edipi: '384759483')

          response = subject.get_dod_service_summary

          expect(response).not_to be_ok
          expect(response.dod_service_summary).to be_nil
        end
      end
    end

    context 'when service returns a 500 error code' do
      it 'raises a BackendServiceException error' do
        VCR.use_cassette('va_profile/military_personnel/dod_service_summary_500') do
          expect { subject.get_dod_service_summary }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(400)
            expect(e.errors.first.code).to eq('VET360_CORE100')
          end
        end
      end
    end
  end
end
