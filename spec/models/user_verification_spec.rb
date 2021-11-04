# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserVerification, type: :model do
  let(:user_verification) do
    create(:user_verification,
           idme_uuid: idme_uuid,
           logingov_uuid: logingov_uuid,
           dslogon_uuid: dslogon_uuid,
           mhv_uuid: mhv_uuid,
           user_account_id: user_account&.id)
  end

  let(:idme_uuid) { nil }
  let(:logingov_uuid) { nil }
  let(:dslogon_uuid) { nil }
  let(:mhv_uuid) { nil }
  let(:user_account) { nil }

  describe 'validations' do
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
            expect(subject).to eq(nil)
          end
        end

        context 'and idme_uuid is defined' do
          let(:idme_uuid) { 'some-idme-uuid' }
          let(:expected_error_message) { 'Validation failed: Must specify one, and only one, credential identifier' }

          it 'returns a validation error' do
            expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
          end
        end
      end

      context 'when another credential is not defined' do
        context 'and idme_uuid is not defined' do
          let(:expected_error_message) { 'Validation failed: Must specify one, and only one, credential identifier' }
          let(:idme_uuid) { nil }

          it 'raises validation error' do
            expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
          end
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
            expect(subject).to eq(nil)
          end
        end

        context 'and logingov_uuid is defined' do
          let(:logingov_uuid) { 'some-logingov-uuid' }
          let(:expected_error_message) { 'Validation failed: Must specify one, and only one, credential identifier' }

          it 'returns a validation error' do
            expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
          end
        end
      end

      context 'when another credential is not defined' do
        context 'and logingov_uuid is not defined' do
          let(:expected_error_message) { 'Validation failed: Must specify one, and only one, credential identifier' }
          let(:logingov_uuid) { nil }

          it 'raises validation error' do
            expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
          end
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
            expect(subject).to eq(nil)
          end
        end

        context 'and dslogon_uuid is defined' do
          let(:dslogon_uuid) { 'some-dslogon-uuid' }
          let(:expected_error_message) { 'Validation failed: Must specify one, and only one, credential identifier' }

          it 'returns a validation error' do
            expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
          end
        end
      end

      context 'when another credential is not defined' do
        context 'and dslogon_uuid is not defined' do
          let(:expected_error_message) { 'Validation failed: Must specify one, and only one, credential identifier' }
          let(:dslogon_uuid) { nil }

          it 'raises validation error' do
            expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
          end
        end

        context 'and dslogon_uuid is defined' do
          let(:dslogon_uuid) { 'some-dslogon-uuid' }

          it 'returns dslogon_uuid' do
            expect(subject).to eq(dslogon_uuid)
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
            expect(subject).to eq(nil)
          end
        end

        context 'and mhv_uuid is defined' do
          let(:mhv_uuid) { 'some-mhv-uuid' }
          let(:expected_error_message) { 'Validation failed: Must specify one, and only one, credential identifier' }

          it 'returns a validation error' do
            expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
          end
        end
      end

      context 'when another credential is not defined' do
        context 'and mhv_uuid is not defined' do
          let(:expected_error_message) { 'Validation failed: Must specify one, and only one, credential identifier' }
          let(:mhv_uuid) { nil }

          it 'raises validation error' do
            expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
          end
        end

        context 'and mhv_uuid is defined' do
          let(:mhv_uuid) { 'some-mhv-uuid' }

          it 'returns mhv_uuid' do
            expect(subject).to eq(mhv_uuid)
          end
        end
      end
    end
  end
end
