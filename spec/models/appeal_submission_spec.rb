# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppealSubmission, type: :model do
  describe '#get_mpi_profile' do
    subject { appeal_submission.get_mpi_profile }

    let(:user) { create(:user, :with_terms_of_use_agreement, :loa3) }
    let(:user_account) { user.user_account }
    let(:mpi_profile) { build(:mpi_profile, icn: user_account.icn) }
    let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }

    let(:appeal_submission) { create(:appeal_submission, user_account:) }
    let(:identifier) { user_account.icn }
    let(:identifier_type) { MPI::Constants::ICN }

    before do
      allow(User).to receive(:find).with(user.uuid).and_return(user)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).with(identifier:, identifier_type:)
                                                                                 .and_return(find_profile_response)
    end

    context 'when a UserAccount with an ICN is present' do
      it 'calls the MPI service with the appropriate identifier and identifier type' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).with(identifier:, identifier_type:)
        subject
      end

      it 'returns the MPI profile' do
        expect(subject).to eq(mpi_profile)
      end
    end

    context 'when a UserAccount with an ICN is not present' do
      let(:find_profile_response) { create(:find_profile_not_found_response) }
      let(:identifier) { nil }
      let(:expected_error) { 'Failed to fetch MPI profile' }

      before { user_account.icn = nil }

      it 'raises an error' do
        expect { subject }.to raise_error(StandardError, expected_error)
      end
    end
  end
end
