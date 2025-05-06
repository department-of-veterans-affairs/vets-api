# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Login::UserCredentialEmailUpdater do
  describe '#perform' do
    subject do
      described_class.new(credential_email:, user_verification:).perform
    end

    let(:credential_email) { 'some-credential-email' }
    let(:user_verification) { 'some-user-verification' }

    context 'when credential email is nil' do
      let(:credential_email) { nil }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when credential email is defined' do
      let(:credential_email) { 'some-credential-email' }

      context 'and user verification is nil' do
        let(:user_verification) { nil }

        it 'returns nil' do
          expect(subject).to be_nil
        end
      end

      context 'and user verification is defined' do
        let(:user_verification) { create(:user_verification) }

        context 'and user credential email already exists associated to the user verification' do
          let!(:user_credential_email) { create(:user_credential_email, user_verification:) }

          it 'does not create a new credential email' do
            expect { subject }.not_to change(UserCredentialEmail, :count)
          end

          it 'saves given credential email on existing user credential email object' do
            subject
            expect(user_credential_email.reload.credential_email).to eq(credential_email)
          end
        end

        context 'and user credential email does not already exist' do
          it 'creates a new credential email' do
            expect { subject }.to change(UserCredentialEmail, :count)
          end

          it 'adds expected attributes to created credential email' do
            subject
            user_credential_email = UserCredentialEmail.last
            expect(user_credential_email.credential_email).to eq(credential_email)
            expect(user_credential_email.user_verification).to eq(user_verification)
          end
        end
      end
    end
  end
end
