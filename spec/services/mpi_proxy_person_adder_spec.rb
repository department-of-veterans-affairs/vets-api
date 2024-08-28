# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MPIProxyPersonAdder do
  subject { described_class.new(icn) }

  let(:icn) { '1234567890' }
  let(:user_account) { create(:user_account, icn:) }
  let(:profile) { build(:mpi_profile) }
  let(:mpi_service) { instance_double(MPI::Service) }

  before do
    allow(UserAccount).to receive(:find_by).with(icn:).and_return(user_account)
    allow(MPI::Service).to receive(:new).and_return(mpi_service)
  end

  describe '#add_person_proxy_by_icn' do
    context 'when profile is present and access is granted' do
      before do
        allow(subject).to receive(:fetch_profile)
        allow(subject).to receive(:profile).and_return(profile)
        allow(MPIPolicy).to receive(:new).with(profile).and_return(instance_double(MPIPolicy,
                                                                                   access_add_person_proxy?: true))
        allow(mpi_service).to receive(:add_person_proxy)
        allow(subject).to receive(:track_proxy_add_success)
      end
      subject { described_class.new(icn) }

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
        subject.add_person_proxy_by_icn
      end

      it 'tracks the proxy add success' do
        expect(subject).to receive(:track_proxy_add_success)
        subject.add_person_proxy_by_icn
      end

      it 'returns true' do
        expect(subject.add_person_proxy_by_icn).to be true
      end
    end

    context 'when profile is not present' do
      before do
        allow(subject).to receive(:fetch_profile)
        allow(subject).to receive(:profile).and_return(nil)
        allow(subject).to receive(:track_proxy_add_skipped)
      end

      it 'does not call MPI service to add person proxy' do
        expect(mpi_service).not_to receive(:add_person_proxy)
        subject.add_person_proxy_by_icn
      end

      it 'tracks the proxy add skipped' do
        expect(subject).to receive(:track_proxy_add_skipped)
        subject.add_person_proxy_by_icn
      end

      it 'returns false' do
        expect(subject.add_person_proxy_by_icn).to be false
      end
    end

    context 'when access is not granted' do
      before do
        allow(subject).to receive(:fetch_profile)
        allow(subject).to receive(:profile).and_return(profile)
        allow(MPIPolicy).to receive(:new).with(profile).and_return(instance_double(MPIPolicy,
                                                                                   access_add_person_proxy?: false))
        allow(subject).to receive(:track_proxy_add_skipped)
      end

      it 'does not call MPI service to add person proxy' do
        expect(mpi_service).not_to receive(:add_person_proxy)
        subject.add_person_proxy_by_icn
      end

      it 'tracks the proxy add skipped' do
        expect(subject).to receive(:track_proxy_add_skipped)
        subject.add_person_proxy_by_icn
      end

      it 'returns false' do
        expect(subject.add_person_proxy_by_icn).to be false
      end
    end

    context 'when an error occurs' do
      let(:error) { StandardError.new('An error occurred') }

      before do
        allow(subject).to receive(:fetch_profile).and_raise(error)
        allow(subject).to receive(:track_proxy_add_failure)
      end

      it 'tracks the proxy add failure' do
        expect(subject).to receive(:track_proxy_add_failure).with(error)
        expect { subject.add_person_proxy_by_icn }.to raise_error(error)
      end
    end
  end
end
