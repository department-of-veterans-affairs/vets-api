# frozen_string_literal: true

require 'rails_helper'

describe PowerOfAttorneyPolicy do
  subject { described_class }

  permissions :access? do
    context 'when user is LOA3, has an ICN, and has a participant_id' do
      let(:user) { build(:user, :loa3) }

      before do
        stub_mpi(build(:mpi_profile, ssn: user.ssn, icn: user.icn, participant_id: user.participant_id))
      end

      it 'grants access' do
        expect(subject).to permit(user, :power_of_attorney)
      end
    end

    context 'when user is LOA3 but does not have an ICN' do
      let(:user) { build(:user, :loa3) }

      before do
        # Ensure user has no ICN by stubbing MPI with nil ICN and mocking user.icn
        stub_mpi(build(:mpi_profile, ssn: user.ssn, icn: nil, participant_id: user.participant_id))
        allow(user).to receive(:icn).and_return(nil)
      end

      it 'denies access due to missing ICN' do
        expect(subject).not_to permit(user, :power_of_attorney)
      end
    end

    context 'when user is LOA3 but does not have a participant_id' do
      let(:user) { build(:user, :loa3) }

      before do
        # Ensure user has no participant_id by stubbing MPI with nil participant_id and mocking user.participant_id
        stub_mpi(build(:mpi_profile, ssn: user.ssn, icn: user.icn, participant_id: nil))
        allow(user).to receive(:participant_id).and_return(nil)
      end

      it 'denies access due to missing participant_id' do
        expect(subject).not_to permit(user, :power_of_attorney)
      end
    end

    context 'when user is not LOA3' do
      let(:user) { build(:user, :loa1) }

      it 'denies access due to not being LOA3' do
        expect(subject).not_to permit(user, :power_of_attorney)
      end
    end
  end
end
