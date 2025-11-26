# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Login::AfterLoginActions do
  subject(:after_login_actions) { described_class.new(user, skip_mhv_account_creation) }

  describe '#perform' do
    let(:skip_mhv_account_creation) { false }

    context 'creating credential email' do
      let(:user) { create(:user, email:) }
      let(:email) { 'some-email' }

      it 'creates a user credential email with expected attributes' do
        expect { after_login_actions.perform }.to change(UserCredentialEmail, :count)
        user_credential_email = user.user_verification.user_credential_email
        expect(user_credential_email.credential_email).to eq(email)
      end
    end

    context 'creating user acceptable verified credential' do
      let(:user) { create(:user) }
      let(:expected_avc_at) { '2021-1-1' }

      before { Timecop.freeze(expected_avc_at) }

      after { Timecop.return }

      it 'creates a user acceptable verified credential with expected attributes' do
        expect do
          after_login_actions.perform
        end.to change(UserAcceptableVerifiedCredential, :count)
        user_avc = UserAcceptableVerifiedCredential.find_by(user_account: user.user_account)
        expect(user_avc.idme_verified_credential_at).to eq(expected_avc_at)
      end
    end

    context 'in a non-staging environment' do
      let(:user) { create(:user) }

      around do |example|
        with_settings(Settings.test_user_dashboard, env: 'production') do
          example.run
        end
      end

      it 'does not call TUD account checkout' do
        expect_any_instance_of(TestUserDashboard::UpdateUser).not_to receive(:call)
        after_login_actions.perform
      end
    end

    context 'in a staging environment' do
      let(:user) { create(:user) }

      around do |example|
        with_settings(Settings.test_user_dashboard, env: 'staging') do
          example.run
        end
      end

      it 'calls TUD account checkout' do
        expect_any_instance_of(TestUserDashboard::UpdateUser).to receive(:call)
        after_login_actions.perform
      end
    end

    context 'UserIdentity & MPI ID validations' do
      let(:mpi_profile) { build(:mpi_profile) }
      let(:loa3_user) { build(:user, :loa3, mpi_profile:) }
      let(:expected_error_data) do
        { identity_value: expected_identity_value, mpi_value: expected_mpi_value, icn: loa3_user.icn }
      end
      let(:expected_error_message) do
        "[SessionsController version:v1] User Identity & MPI #{validation_id} values conflict"
      end

      before do
        allow(Rails.logger).to receive(:warn)
      end

      shared_examples 'identity-mpi id validation' do
        it 'logs a warning when Identity & MPI values conflict' do
          expect(Rails.logger).to receive(:warn).at_least(:once).with(expected_error_message, expected_error_data)
          described_class.new(loa3_user, skip_mhv_account_creation).perform
        end
      end

      context 'ssn validation' do
        let(:mpi_profile) { build(:mpi_profile, { ssn: Faker::Number.number(digits: 9) }) }
        let(:expected_identity_value) { loa3_user.identity.ssn }
        let(:expected_mpi_value) { loa3_user.ssn_mpi }
        let(:validation_id) { 'SSN' }
        let(:expected_error_data) { { icn: loa3_user.icn } }

        it_behaves_like 'identity-mpi id validation'
      end

      context 'edipi validation' do
        let(:mpi_profile) { build(:mpi_profile, { edipi: Faker::Number.number(digits: 10) }) }
        let(:expected_identity_value) { loa3_user.identity.edipi }
        let(:expected_mpi_value) { loa3_user.edipi_mpi }
        let(:validation_id) { 'EDIPI' }

        it_behaves_like 'identity-mpi id validation'
      end

      context 'icn validation' do
        let(:mpi_profile) { build(:mpi_profile, { icn: '1234567V01112538' }) }
        let(:expected_identity_value) { loa3_user.identity.icn }
        let(:expected_mpi_value) { loa3_user.mpi_icn }
        let(:validation_id) { 'ICN' }

        it_behaves_like 'identity-mpi id validation'
      end
    end

    context 'when creating an MHV account' do
      let(:user) { create(:user) }

      before do
        allow(user).to receive(:create_mhv_account_async)
      end

      context 'when skip_mhv_account_creation is set to false' do
        let(:skip_mhv_account_creation) { false }

        it 'calls create_mhv_account_async' do
          after_login_actions.perform
          expect(user).to have_received(:create_mhv_account_async)
        end
      end

      context 'when skip_mhv_account_creation is set to true' do
        let(:skip_mhv_account_creation) { true }

        it 'does not call create_mhv_account_async' do
          after_login_actions.perform
          expect(user).not_to have_received(:create_mhv_account_async)
        end
      end
    end

    context 'when the user can provision cerner' do
      let(:user) { create(:user, :loa3, cerner_id:) }
      let(:cerner_id) { 'some-cerner-id' }

      before do
        allow(Identity::CernerProvisionerJob).to receive(:perform_async)
      end

      it 'enqueues a Cerner::ProvisionerJob' do
        after_login_actions.perform
        expect(Identity::CernerProvisionerJob).to have_received(:perform_async).with(user.icn, :ssoe)
      end
    end
  end
end
