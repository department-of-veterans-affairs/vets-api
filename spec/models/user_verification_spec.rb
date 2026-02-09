# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserVerification, type: :model do
  let(:user_verification) do
    create(:user_verification,
           idme_uuid:,
           logingov_uuid:,
           dslogon_uuid:,
           mhv_uuid:,
           backing_idme_uuid:,
           verified_at:,
           user_account_id: user_account&.id,
           locked:)
  end

  let(:idme_uuid) { nil }
  let(:logingov_uuid) { nil }
  let(:dslogon_uuid) { nil }
  let(:mhv_uuid) { nil }
  let(:user_account) { nil }
  let(:backing_idme_uuid) { nil }
  let(:verified_at) { nil }
  let(:locked) { false }

  describe 'validations' do
    shared_examples 'failed credential identifier validation' do
      let(:expected_error_message) { 'Validation failed: Must specify one, and only one, credential identifier' }

      it 'raises validation error' do
        expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
      end
    end

    shared_examples 'failed backing uuid credentials validation' do
      let(:expected_error_message) do
        'Validation failed: Must define either an idme_uuid, logingov_uuid, or backing_idme_uuid'
      end

      it 'raises validation error' do
        expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
      end
    end

    shared_examples 'failed both validations' do
      let(:expected_error_message) do
        'Validation failed: Must specify one, and only one, credential identifier, ' \
          'Must define either an idme_uuid, logingov_uuid, or backing_idme_uuid'
      end

      it 'raises validation error' do
        expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
      end
    end

    describe '#user_account' do
      subject { user_verification.user_account }

      let(:idme_uuid) { 'banana' }

      context 'when user_account is nil' do
        let(:user_account) { nil }
        let(:expected_error_message) { 'Validation failed: User account must exist' }

        it 'raises validation error' do
          expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
        end
      end

      context 'when user_account is not nil' do
        let(:user_account) { create(:user_account) }

        it 'returns the user account' do
          expect(subject).to eq(user_account)
        end
      end
    end

    describe '#idme_uuid' do
      subject { user_verification.idme_uuid }

      let(:user_account) { create(:user_account) }

      context 'when another credential is defined' do
        let(:logingov_uuid) { 'some-logingov-id' }

        context 'and idme_uuid is not defined' do
          it 'returns nil' do
            expect(subject).to be_nil
          end
        end

        context 'and idme_uuid is defined' do
          let(:idme_uuid) { 'some-idme-uuid' }

          it_behaves_like 'failed credential identifier validation'
        end
      end

      context 'when another credential is not defined' do
        context 'and idme_uuid is not defined' do
          let(:idme_uuid) { nil }

          it_behaves_like 'failed both validations'
        end

        context 'and idme_uuid is defined' do
          let(:idme_uuid) { 'some-idme-uuid' }

          it 'returns idme_uuid' do
            expect(subject).to eq(idme_uuid)
          end
        end
      end
    end

    describe '#logingov_uuid' do
      subject { user_verification.logingov_uuid }

      let(:user_account) { create(:user_account) }

      context 'when another credential is defined' do
        let(:idme_uuid) { 'some-idme-uuid-id' }

        context 'and logingov_uuid is not defined' do
          it 'returns nil' do
            expect(subject).to be_nil
          end
        end

        context 'and logingov_uuid is defined' do
          let(:logingov_uuid) { 'some-logingov-uuid' }

          it_behaves_like 'failed credential identifier validation'
        end
      end

      context 'when another credential is not defined' do
        context 'and logingov_uuid is not defined' do
          let(:logingov_uuid) { nil }

          it_behaves_like 'failed both validations'
        end

        context 'and logingov_uuid is defined' do
          let(:logingov_uuid) { 'some-logingov-uuid' }

          it 'returns logingov_uuid' do
            expect(subject).to eq(logingov_uuid)
          end
        end
      end
    end

    describe '#dslogon_uuid' do
      subject { user_verification.dslogon_uuid }

      let(:user_account) { create(:user_account) }

      context 'when another credential is defined' do
        let(:idme_uuid) { 'some-idme-uuid-id' }

        context 'and dslogon_uuid is not defined' do
          it 'returns nil' do
            expect(subject).to be_nil
          end
        end

        context 'and dslogon_uuid is defined' do
          let(:dslogon_uuid) { 'some-dslogon-uuid' }

          it_behaves_like 'failed credential identifier validation'
        end
      end

      context 'when another credential is not defined' do
        context 'and dslogon_uuid is not defined' do
          let(:dslogon_uuid) { nil }

          it_behaves_like 'failed both validations'
        end

        context 'and dslogon_uuid is defined' do
          let(:dslogon_uuid) { 'some-dslogon-uuid' }

          context 'and backing_idme_uuid is not defined' do
            let(:backing_idme_uuid) { nil }

            it_behaves_like 'failed backing uuid credentials validation'
          end

          context 'and backing_idme_uuid is defined' do
            let(:backing_idme_uuid) { 'some-backing-idme-uuid' }

            it 'returns dslogon_uuid' do
              expect(subject).to eq(dslogon_uuid)
            end
          end
        end
      end
    end

    describe '#mhv_uuid' do
      subject { user_verification.mhv_uuid }

      let(:user_account) { create(:user_account) }

      context 'when another credential is defined' do
        let(:idme_uuid) { 'some-idme-uuid-id' }

        context 'and mhv_uuid is not defined' do
          it 'returns nil' do
            expect(subject).to be_nil
          end
        end

        context 'and mhv_uuid is defined' do
          let(:mhv_uuid) { 'some-mhv-uuid' }

          it_behaves_like 'failed credential identifier validation'
        end
      end

      context 'when another credential is not defined' do
        context 'and mhv_uuid is not defined' do
          let(:mhv_uuid) { nil }

          it_behaves_like 'failed both validations'
        end

        context 'and mhv_uuid is defined' do
          let(:mhv_uuid) { 'some-mhv-uuid' }

          context 'and backing_idme_uuid is not defined' do
            let(:backing_idme_uuid) { nil }

            it_behaves_like 'failed backing uuid credentials validation'
          end

          context 'and backing_idme_uuid is defined' do
            let(:backing_idme_uuid) { 'some-backing-idme-uuid' }

            it 'returns mhv_uuid' do
              expect(subject).to eq(mhv_uuid)
            end
          end
        end
      end
    end
  end

  describe '.lock!' do
    subject { user_verification.lock! }

    let(:user_account) { create(:user_account) }
    let(:logingov_uuid) { SecureRandom.uuid }

    it 'updates locked to true' do
      expect { subject }.to change(user_verification, :locked).from(false).to(true)
    end
  end

  describe '.unlock!' do
    subject { user_verification.unlock! }

    let(:user_account) { create(:user_account) }
    let(:logingov_uuid) { SecureRandom.uuid }
    let(:locked) { true }

    it 'updates locked to false' do
      expect { subject }.to change(user_verification, :locked).from(true).to(false)
    end
  end

  describe '.find_by_type!' do
    subject { UserVerification.find_by_type!(type, identifier) }

    let(:user_account) { create(:user_account) }

    context 'when a user verification is not found' do
      let(:identifier) { 'some-identifier' }
      let(:type) { 'logingov' }

      it 'raises a record not found error' do
        expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when a user verification is found' do
      let(:identifier) { user_verification.credential_identifier }

      context 'when a Login.gov user verification is found' do
        let(:logingov_uuid) { 'some-logingov-uuid' }
        let(:type) { 'logingov' }

        it 'returns the user verification' do
          expect(subject).to eq(user_verification)
        end
      end

      context 'when an ID.me user verification is found' do
        let(:idme_uuid) { 'some-idme-uuid' }
        let(:type) { 'idme' }

        it 'returns the user verification' do
          expect(subject).to eq(user_verification)
        end
      end

      context 'when a DSLogon user verification is found' do
        let(:dslogon_uuid) { 'some-dslogon-uuid' }
        let(:backing_idme_uuid) { 'some-backing-idme-uuid' }
        let(:type) { 'dslogon' }

        it 'returns the user verification' do
          expect(subject).to eq(user_verification)
        end
      end

      context 'when an MHV user verification is found' do
        let(:mhv_uuid) { 'some-mhv-uuid' }
        let(:backing_idme_uuid) { 'some-backing-idme-uuid' }
        let(:type) { 'mhv' }

        it 'returns the user verification' do
          expect(subject).to eq(user_verification)
        end
      end
    end
  end

  describe '#verified?' do
    subject { user_verification.verified? }

    let(:idme_uuid) { 'some-idme-uuid' }

    context 'when user_account is verified' do
      let(:user_account) { create(:user_account) }

      context 'and verified_at is defined' do
        let(:verified_at) { Time.zone.now }

        it 'returns true' do
          expect(subject).to be true
        end
      end

      context 'and verified_at is not defined' do
        let(:verified_at) { nil }

        it 'returns false' do
          expect(subject).to be false
        end
      end
    end

    context 'when user_account is not verified' do
      let(:user_account) { create(:user_account, icn: nil) }

      it 'returns false' do
        expect(subject).to be false
      end
    end
  end

  describe '#credential_type' do
    subject { user_verification.credential_type }

    let(:user_account) { create(:user_account) }

    context 'when idme_uuid is present' do
      let(:idme_uuid) { 'some-idme-uuid' }
      let(:expected_credential_type) { SAML::User::IDME_CSID }

      it 'returns expected credential type' do
        expect(subject).to eq(expected_credential_type)
      end
    end

    context 'when mhv_uuid is present' do
      let(:mhv_uuid) { 'some-mhv-uuid' }
      let(:backing_idme_uuid) { 'some-backing-idme-uuid' }
      let(:expected_credential_type) { SAML::User::MHV_ORIGINAL_CSID }

      it 'returns expected credential type' do
        expect(subject).to eq(expected_credential_type)
      end
    end

    context 'when logingov_uuid is present' do
      let(:logingov_uuid) { 'some-logingov-uuid' }
      let(:expected_credential_type) { SAML::User::LOGINGOV_CSID }

      it 'returns expected credential type' do
        expect(subject).to eq(expected_credential_type)
      end
    end
  end

  describe '#credential_identifier' do
    subject { user_verification.credential_identifier }

    let(:user_account) { create(:user_account) }

    context 'when idme_uuid is present' do
      let(:idme_uuid) { 'some-idme-uuid' }
      let(:expected_credential_identifier) { idme_uuid }

      it 'returns expected credential identifier' do
        expect(subject).to eq(expected_credential_identifier)
      end
    end

    context 'when dslogon_uuid is present' do
      let(:dslogon_uuid) { 'some-dslogon-uuid' }
      let(:backing_idme_uuid) { 'some-backing-idme-uuid' }
      let(:expected_credential_identifier) { dslogon_uuid }

      it 'returns expected credential identifier' do
        expect(subject).to eq(expected_credential_identifier)
      end
    end

    context 'when mhv_uuid is present' do
      let(:mhv_uuid) { 'some-mhv-uuid' }
      let(:backing_idme_uuid) { 'some-backing-idme-uuid' }
      let(:expected_credential_identifier) { mhv_uuid }

      it 'returns expected credential identifier' do
        expect(subject).to eq(expected_credential_identifier)
      end
    end

    context 'when logingov_uuid is present' do
      let(:logingov_uuid) { 'some-logingov-uuid' }
      let(:expected_credential_identifier) { logingov_uuid }

      it 'returns expected credential identifier' do
        expect(subject).to eq(expected_credential_identifier)
      end
    end
  end

  describe '#backing_credential_identifier' do
    subject { user_verification.backing_credential_identifier }

    let(:user_account) { create(:user_account) }

    context 'when logingov_uuid is present' do
      let(:logingov_uuid) { 'some-logingov-uuid' }
      let(:expected_identifier) { logingov_uuid }

      it 'returns logingov_uuid identifier' do
        expect(subject).to eq(expected_identifier)
      end
    end

    context 'when logingov_uuid is not present' do
      let(:logingov_uuid) { nil }

      context 'and idme_uuid is present' do
        let(:idme_uuid) { 'some-idme-uuid' }
        let(:expected_identifier) { idme_uuid }

        it 'returns idme_uuid identifier' do
          expect(subject).to eq(expected_identifier)
        end
      end

      context 'and idme_uuid is not present' do
        let(:idme_uuid) { nil }
        let(:mhv_uuid) { 'some-mhv-uuid' }
        let(:backing_idme_uuid) { 'some-backing-idme-uuid' }
        let(:expected_identifier) { backing_idme_uuid }

        it 'returns backing_idme_uuid identifier' do
          expect(subject).to eq(expected_identifier)
        end
      end
    end
  end
end
