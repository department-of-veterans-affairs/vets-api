# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppealSubmission, type: :model do
  describe '#get_mpi_profile' do
    subject { appeal_submission.get_mpi_profile }

    let(:user_account) { create(:user_account) }
    let(:user) { create(:user, :with_terms_of_use_agreement, :loa3, icn: user_account.icn) }
    let(:mpi_profile) { build(:mpi_profile, icn: user_account.icn) }
    let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }

    let(:appeal_submission) { create(:appeal_submission, user_uuid: user.uuid, user_account:) }
    let(:identifier) { user_account.icn }
    let(:identifier_type) { MPI::Constants::ICN }

    before do
      allow(User).to receive(:find).with(user.uuid).and_return(user)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).with(identifier:, identifier_type:)
                                                                                 .and_return(find_profile_response)
    end

    shared_examples 'calls the MPI service with the appropriate identifier and identifier type' do
      it 'calls the MPI service with the appropriate identifier and identifier type' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).with(identifier:, identifier_type:)
        subject
      end
    end

    context 'when a UserAccount with an ICN is present' do
      it_behaves_like 'calls the MPI service with the appropriate identifier and identifier type'
    end

    context 'when a UserAccount with an ICN is not present' do
      before { user_account.icn = nil }

      context 'when a UserVerification with an ID.me uuid is present' do
        let(:idme_user_verification) { create(:idme_user_verification, user_account:) }
        let(:identifier) { idme_user_verification.idme_uuid }
        let(:identifier_type) { MPI::Constants::IDME_UUID }

        it_behaves_like 'calls the MPI service with the appropriate identifier and identifier type'
      end

      context 'when a UserVerification with an ID.me uuid is not present' do
        context 'when a UserVerification with a Logingov uuid is present' do
          let(:logingov_user_verification) { create(:logingov_user_verification, user_account:) }
          let(:identifier) { logingov_user_verification.logingov_uuid }
          let(:identifier_type) { MPI::Constants::LOGINGOV_UUID }

          it_behaves_like 'calls the MPI service with the appropriate identifier and identifier type'
        end

        context 'when a UserVerification with a Logingov uuid is not present' do
          context 'when the User model exists in Redis & has an ID.me uuid' do
            let(:identifier) { user.idme_uuid }
            let(:identifier_type) { MPI::Constants::IDME_UUID }

            it_behaves_like 'calls the MPI service with the appropriate identifier and identifier type'
          end

          context 'when the User model exists in Redis & does not have an ID.me uuid' do
            before { allow(user).to receive(:idme_uuid).and_return(nil) }

            context 'when the User model exists in Redis & has a Logingov uuid' do
              let(:user) { create(:user, :accountable_with_logingov_uuid, icn: user_account.icn) }
              let(:identifier) { user.logingov_uuid }
              let(:identifier_type) { MPI::Constants::LOGINGOV_UUID }

              it_behaves_like 'calls the MPI service with the appropriate identifier and identifier type'
            end

            context 'when the User model exists in Redis & does not have a Logingov uuid' do
              let(:expected_error) { 'Failed to fetch MPI profile' }

              it 'does not attempt to query MPI for a profile & raises an error' do
                expect_any_instance_of(MPI::Service).not_to receive(:find_profile_by_identifier)
                expect { subject }.to raise_error(StandardError, expected_error)
              end
            end
          end
        end
      end
    end

    context 'when the MPI request is successful' do
      it 'returns the MPI profile' do
        expect(subject).to eq(mpi_profile)
      end
    end
  end
end
