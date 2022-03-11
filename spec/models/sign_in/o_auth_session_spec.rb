# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::OAuthSession, type: :model do
  let(:oauth_session) do
    create(:oauth_session,
           user_account: user_account,
           handle: handle,
           hashed_refresh_token: hashed_refresh_token,
           refresh_expiration: refresh_expiration,
           refresh_creation: refresh_creation)
  end

  let(:user_account) { create(:user_account) }
  let(:handle) { SecureRandom.hex }
  let(:hashed_refresh_token) { SecureRandom.hex }
  let(:refresh_expiration) { Time.zone.now + 1000 }
  let(:refresh_creation) { Time.zone.now }

  describe 'validations' do
    describe '#user_account' do
      subject { oauth_session.user_account }

      context 'when user_account is nil' do
        let(:user_account) { nil }
        let(:expected_error_message) { 'Validation failed: User account must exist' }

        it 'raises validation error' do
          expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
        end
      end
    end

    describe '#handle' do
      subject { oauth_session.handle }

      context 'when handle is nil' do
        let(:handle) { nil }
        let(:expected_error_message) { "Validation failed: Handle can't be blank" }

        it 'raises validation error' do
          expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
        end
      end

      context 'when handle is duplicate' do
        let!(:oauth_session_dup) { create(:oauth_session, handle: handle) }
        let(:expected_error_message) { 'Validation failed: Handle has already been taken' }

        it 'raises validation error' do
          expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
        end
      end
    end

    describe '#hashed_refresh_token' do
      subject { oauth_session.hashed_refresh_token }

      context 'when hashed_refresh_token is nil' do
        let(:hashed_refresh_token) { nil }
        let(:expected_error_message) { "Validation failed: Hashed refresh token can't be blank" }

        it 'raises validation error' do
          expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
        end
      end

      context 'when hashed_refresh_token is duplicate' do
        let!(:oauth_session_dup) { create(:oauth_session, hashed_refresh_token: hashed_refresh_token) }
        let(:expected_error_message) { 'Validation failed: Hashed refresh token has already been taken' }

        it 'raises validation error' do
          expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
        end
      end
    end

    describe '#refresh_expiration' do
      subject { oauth_session.refresh_expiration }

      context 'when refresh_expiration is nil' do
        let(:refresh_expiration) { nil }
        let(:expected_error_message) { "Validation failed: Refresh expiration can't be blank" }

        it 'raises validation error' do
          expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
        end
      end
    end

    describe '#refresh_creation' do
      subject { oauth_session.refresh_creation }

      context 'when refresh_creation is nil' do
        let(:refresh_creation) { nil }
        let(:expected_error_message) { "Validation failed: Refresh creation can't be blank" }

        it 'raises validation error' do
          expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
        end
      end
    end
  end

  describe '#active?' do
    subject { oauth_session.active? }

    let(:current_time) { Time.zone.now }

    context 'when current time is before refresh_expiration' do
      let(:refresh_expiration) { current_time + 1000 }

      it 'returns true' do
        expect(subject).to be true
      end
    end

    context 'when current time is after refresh_expiration' do
      let(:refresh_expiration) { current_time - 1000 }

      it 'returns false' do
        expect(subject).to be false
      end
    end

    context 'when current time is equal to refresh_expiration' do
      let(:refresh_expiration) { current_time }

      it 'returns false' do
        expect(subject).to be false
      end
    end
  end
end
