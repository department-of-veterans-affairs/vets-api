# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Login::UserAcceptableVerifiedCredentialUpdater do
  describe '#perform' do
    subject do
      described_class.new(user_account: user_account).perform
    end

    let(:user_account) { 'some-user_account' }

    context 'when user account is nil' do
      let(:user_account) { nil }

      it 'returns nil' do
        expect(subject).to eq nil
      end
    end

    context 'when user account is defined' do
      let(:user_account) { create(:user_account, icn: icn) }
      let(:icn) { 'some-icn' }

      context 'and user account is not verified' do
        let(:icn) { nil }

        it 'returns nil' do
          expect(subject).to eq nil
        end
      end

      context 'and user account is verified' do
        let(:icn) { 'some-icn' }
        let(:expected_verified_credential_at) { '2023-1-1' }

        before { Timecop.freeze(expected_verified_credential_at) }

        after { Timecop.return }

        context 'and user acceptable verified credential already exists associated to the user account' do
          let!(:user_avc) { create(:user_acceptable_verified_credential, user_account: user_account) }

          it 'does not create a new acceptable verified credential' do
            expect { subject }.not_to change(UserAcceptableVerifiedCredential, :count)
          end
        end

        context 'and user acceptable verified credential does not already exist associated to the user account' do
          it 'creates a new acceptable verified credential' do
            expect { subject }.to change(UserAcceptableVerifiedCredential, :count)
          end
        end

        context 'and user account is associated with an idme user verification' do
          let!(:user_verification) { create(:idme_user_verification, user_account: user_account) }
          let(:expected_avc_at) { nil }
          let(:expected_ivc_at) { expected_verified_credential_at }

          it 'updates acceptable verified credential at value' do
            subject
            user_avc = UserAcceptableVerifiedCredential.last
            expect(user_avc.acceptable_verified_credential_at).to eq(expected_avc_at)
            expect(user_avc.idme_verified_credential_at).to eq(expected_ivc_at)
          end
        end

        context 'and user account is associated with a logingov user verification' do
          let!(:user_verification) { create(:logingov_user_verification, user_account: user_account) }
          let(:expected_avc_at) { expected_verified_credential_at }
          let(:expected_ivc_at) { nil }

          it 'updates acceptable verified credential at value' do
            subject
            user_avc = UserAcceptableVerifiedCredential.last
            expect(user_avc.acceptable_verified_credential_at).to eq(expected_avc_at)
            expect(user_avc.idme_verified_credential_at).to eq(expected_ivc_at)
          end
        end

        context 'and user account is not associated with either an idme or logingov user verification' do
          let!(:user_verification) { create(:dslogon_user_verification, user_account: user_account) }
          let(:expected_avc_at) { nil }
          let(:expected_ivc_at) { nil }

          it 'does not update verified credential at values' do
            subject
            user_avc = UserAcceptableVerifiedCredential.last
            expect(user_avc.acceptable_verified_credential_at).to eq(expected_avc_at)
            expect(user_avc.idme_verified_credential_at).to eq(expected_ivc_at)
          end
        end
      end
    end
  end
end
