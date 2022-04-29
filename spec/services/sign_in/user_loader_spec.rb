# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::UserLoader do
  describe '#perform' do
    subject { SignIn::UserLoader.new(access_token: access_token).perform }

    let(:access_token) { create(:access_token, user_uuid: user.uuid, session_handle: session_handle) }
    let(:user) { create(:user, :loa3, uuid: user_uuid, loa: user_loa, icn: user_icn) }
    let(:user_uuid) { user_account.id }
    let(:user_account) { create(:user_account) }
    let(:user_loa) { { current: LOA::THREE, highest: LOA::THREE } }
    let(:user_icn) { user_account.icn }
    let(:session) { create(:oauth_session) }
    let(:session_handle) { session.handle }

    context 'when user record already exists in redis' do
      let(:user_uuid) { user_account.id }

      it 'returns existing user redis record' do
        expect(subject.uuid).to eq(user_uuid)
      end
    end

    context 'when user record no longer exists in redis' do
      before do
        user.destroy
      end

      context 'and associated user account cannot be found' do
        let(:user_account) { nil }
        let(:user_uuid) { 'some-user-uuid' }
        let(:user_icn) { 'some-user-icn' }
        let(:expected_error) { SignIn::Errors::UserAccountNotFoundError }

        it 'raises a user account not found error' do
          expect { subject }.to raise_error(expected_error)
        end
      end

      context 'and associated user account exists' do
        let(:user_account) { create(:user_account) }

        context 'and associated session cannot be found' do
          let(:session) { nil }
          let(:session_handle) { 'some-not-found-session-handle' }
          let(:expected_error) { SignIn::Errors::SessionNotFoundError }

          it 'raises a session not found error' do
            expect { subject }.to raise_error(expected_error)
          end
        end

        context 'and associated session exists' do
          let(:session) { create(:oauth_session) }
          let(:edipi) { 'some-mpi-edipi' }

          before do
            stub_mpi(build(:mvi_profile, edipi: edipi))
          end

          it 'reloads user object with expected attributes' do
            reloaded_user = subject
            expect(reloaded_user.uuid).to eq(user_uuid)
            expect(reloaded_user.loa).to eq(user_loa)
            expect(reloaded_user.mhv_icn).to eq(user_icn)
            expect(reloaded_user.last_signed_in).to eq(session.created_at)
          end

          it 'reloads user object so that MPI can be called for additional attributes' do
            expect(subject.edipi).to be edipi
          end
        end
      end
    end
  end
end
