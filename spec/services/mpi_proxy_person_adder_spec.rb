# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MPIProxyPersonAdder do
  subject { described_class.new(icn) }

  let(:icn) { '1234567890' }
  let(:user_account) { create(:user_account, icn:) }
  let(:profile) { build(:mpi_profile) }
  let(:mpi_service) { instance_double(MPI::Service) }
  let(:monitor) { instance_double(MPIProxyPersonAdder::Monitor) }

  before do
    allow(UserAccount).to receive(:find_by).with(icn:).and_return(user_account)
    allow(MPI::Service).to receive(:new).and_return(mpi_service)
    allow(monitor).to receive_messages(track_proxy_add_begun: nil, track_proxy_add_success: nil,
                                       track_proxy_add_skipped: nil, track_proxy_add_failure: nil)

    subject.instance_variable_set(:@monitor, monitor)
  end

  describe '#add_person_proxy_by_icn' do
    context 'when profile is present and access is granted' do
      before do
        policy = instance_double(MPIPolicy, access_add_person_proxy?: true)
        allow(MPIPolicy).to receive(:new).with(profile).and_return(policy)

        allow(mpi_service).to receive(:add_person_proxy)
        allow(mpi_service).to receive(:find_profile_by_identifier).and_return(OpenStruct.new(profile:))

        expect(monitor).to receive(:track_proxy_add_success)
      end

      it 'calls MPI service to add person proxy' do
        expect(mpi_service).to receive(:add_person_proxy).with(
          first_name: profile.given_names.first,
          last_name: profile.family_name,
          ssn: profile.ssn,
          birth_date: Formatters::DateFormatter.format_date(profile.birth_date),
          icn: profile.icn,
          edipi: profile.edipi,
          search_token: profile.search_token
        )
        expect(MPIProxyPersonAdder).to receive(:new).and_return(subject)

        MPIProxyPersonAdder.add_person_proxy_by_icn(icn)
      end

      it 'returns true' do
        expect(subject.add_person_proxy_by_icn).to be true
      end
    end

    context 'when profile is not present' do
      before do
        allow(mpi_service).to receive(:find_profile_by_identifier).and_return(OpenStruct.new(profile: nil))

        allow(monitor).to receive(:track_proxy_add_skipped)
      end

      it 'does not call MPI service to add person proxy' do
        expect(mpi_service).not_to receive(:add_person_proxy)
        subject.add_person_proxy_by_icn
      end

      it 'tracks the proxy add skipped' do
        expect(monitor).to receive(:track_proxy_add_skipped)
        subject.add_person_proxy_by_icn
      end

      it 'returns false' do
        expect(subject.add_person_proxy_by_icn).to be false
      end
    end

    context 'when access is not granted' do
      before do
        policy = instance_double(MPIPolicy, access_add_person_proxy?: false)
        allow(MPIPolicy).to receive(:new).with(profile).and_return(policy)

        allow(mpi_service).to receive(:find_profile_by_identifier).and_return(OpenStruct.new(profile:))

        allow(monitor).to receive(:track_proxy_add_skipped)
      end

      it 'does not call MPI service to add person proxy' do
        expect(mpi_service).not_to receive(:add_person_proxy)
        subject.add_person_proxy_by_icn
      end

      it 'tracks the proxy add skipped' do
        expect(monitor).to receive(:track_proxy_add_skipped)
        subject.add_person_proxy_by_icn
      end

      it 'returns false' do
        expect(subject.add_person_proxy_by_icn).to be false
      end
    end

    context 'when an error occurs' do
      let(:error) { StandardError.new('An error occurred') }

      before do
        allow(mpi_service).to receive(:find_profile_by_identifier).and_return(OpenStruct.new(error:))

        allow(monitor).to receive(:track_proxy_add_failure)
      end

      it 'tracks the proxy add failure' do
        expect(monitor).to receive(:track_proxy_add_failure).with(error)
        expect { subject.add_person_proxy_by_icn }.to raise_error(error)
      end
    end
  end

  describe '#monitor' do
    it 'sets the instance variable' do
      subject.instance_variable_set(:@monitor, nil)
      expect(MPIProxyPersonAdder::Monitor).to receive(:new).with(user_account.id)
      subject.send(:monitor)
    end
  end

  describe '#fetch_profile' do
    it 'raises ArgumentError' do
      subject.instance_variable_set(:@icn, nil)
      expect { subject.send(:fetch_profile) }.to raise_error(ArgumentError, /Missing ICN/)
    end

    it 'catches and raises the MPI error' do
      error_response = OpenStruct.new(error: MPI::Errors::RecordNotFound)
      allow(mpi_service).to receive(:find_profile_by_identifier).and_return(error_response)

      expect(monitor).to receive(:track_proxy_add_failure)
      expect { subject.send(:fetch_profile) }.to raise_error(MPI::Errors::RecordNotFound)
    end
  end

  describe MPIProxyPersonAdder::Monitor do
    subject { described_class.new(user_account_uuid) }

    let(:source) { described_class::MPI_PROXY_PERSON_ADDER_PATH }
    let(:user_account_uuid) { 'TEST123' }

    before do
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive_messages(info: nil, warn: nil)
    end

    describe '#track_proxy_add_begun' do
      it 'logs proxy add begun' do
        expect(StatsD).to receive(:increment).with(/\.begun/)
        expect(Rails.logger).to receive(:info).with(/begun/, { source:, user_account_uuid: })

        subject.track_proxy_add_begun
      end
    end

    describe '#track_proxy_add_success' do
      it 'logs proxy add success' do
        expect(StatsD).to receive(:increment).with(/\.success/)
        expect(Rails.logger).to receive(:info).with(/success/, { source:, user_account_uuid: })

        subject.track_proxy_add_success
      end
    end

    describe '#track_proxy_add_skipped' do
      it 'logs proxy add skipped' do
        expect(StatsD).to receive(:increment).with(/\.skipped/)
        expect(Rails.logger).to receive(:info).with(/skipped/, { source:, user_account_uuid: })

        subject.track_proxy_add_skipped
      end
    end

    describe '#track_proxy_add_failure' do
      it 'logs proxy add failure' do
        expect(StatsD).to receive(:increment).with(/\.failure/)
        expect(Rails.logger).to receive(:warn).with(/failure/, { source:, user_account_uuid:, error: 'test error' })

        subject.track_proxy_add_failure('test error')
      end
    end
  end
end
