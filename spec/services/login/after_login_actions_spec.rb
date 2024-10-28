# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Login::AfterLoginActions do
  describe '#perform' do
    context 'creating credential email' do
      let(:user) { create(:user, email:, idme_uuid:) }
      let!(:user_verification) { create(:idme_user_verification, idme_uuid:) }
      let(:idme_uuid) { 'some-idme-uuid' }
      let(:email) { 'some-email' }

      it 'creates a user credential email with expected attributes' do
        expect { described_class.new(user).perform }.to change(UserCredentialEmail, :count)
        user_credential_email = user.user_verification.user_credential_email
        expect(user_credential_email.credential_email).to eq(email)
      end
    end

    context 'creating user acceptable verified credential' do
      let(:user) { create(:user, idme_uuid:) }
      let!(:user_verification) { create(:idme_user_verification, idme_uuid:) }
      let(:idme_uuid) { 'some-idme-uuid' }
      let(:expected_avc_at) { '2021-1-1' }

      before { Timecop.freeze(expected_avc_at) }

      after { Timecop.return }

      it 'creates a user acceptable verified credential with expected attributes' do
        expect { described_class.new(user).perform }.to change(UserAcceptableVerifiedCredential, :count)
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
        described_class.new(user).perform
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
        described_class.new(user).perform
      end
    end

    context 'saving account_login_stats' do
      let(:user) { create(:user) }
      let(:login_type) { SAML::User::MHV_ORIGINAL_CSID }
      let(:login_type_stat) { SAML::User::MHV_MAPPED_CSID }

      before { allow_any_instance_of(UserIdentity).to receive(:sign_in).and_return(service_name: login_type) }

      context 'with non-existent login stats record' do
        it 'creates an account_login_stats record' do
          expect { described_class.new(user).perform }.to \
            change(AccountLoginStat, :count).by(1)
        end

        it 'updates the correct login stats column' do
          described_class.new(user).perform
          expect(AccountLoginStat.last.send("#{login_type_stat}_at")).not_to be_nil
        end

        it 'updates the current_verification column' do
          described_class.new(user).perform
          expect(AccountLoginStat.last.current_verification).to eq('loa1')
        end

        it 'does not create a record if login_type is not valid' do
          login_type = 'something_invalid'
          allow_any_instance_of(UserIdentity).to receive(:sign_in).and_return(service_name: login_type)

          expect { described_class.new(user).perform }.not_to \
            change(AccountLoginStat, :count)
        end
      end

      context 'with existing login stats record' do
        let(:account) { FactoryBot.create(:account) }

        before do
          allow_any_instance_of(User).to receive(:account) { account }
          AccountLoginStat.create(account_id: account.id, myhealthevet_at: 1.minute.ago)
        end

        it 'does not create another record' do
          expect { described_class.new(user).perform }.not_to \
            change(AccountLoginStat, :count)
        end

        it 'overwrites existing value if login type was seen previously' do
          stat = AccountLoginStat.last

          expect do
            described_class.new(user).perform
            stat.reload
          end.to change(stat, :myhealthevet_at)
        end

        it 'sets new value in blank login column' do
          login_type = SAML::User::IDME_CSID
          allow_any_instance_of(UserIdentity).to receive(:sign_in).and_return(service_name: login_type)
          stat = AccountLoginStat.last

          expect do
            described_class.new(user).perform
            stat.reload
          end.not_to change(stat, :myhealthevet_at)

          expect(stat.idme_at).not_to be_blank
        end

        it 'triggers sentry error if update fails' do
          allow_any_instance_of(AccountLoginStat).to receive(:update!).and_raise('Failure!')
          expect_any_instance_of(described_class).to receive(:log_error)
          described_class.new(user).perform
        end
      end

      context 'with a non-existant account' do
        before { allow_any_instance_of(User).to receive(:account).and_return(nil) }

        it 'triggers sentry error message' do
          expect_any_instance_of(described_class).to receive(:no_account_log_message)
          expect { described_class.new(user).perform }.not_to \
            change(AccountLoginStat, :count)
        end
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
          described_class.new(loa3_user).perform
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

      context 'MHV correlation id validation' do
        let(:expected_identity_value) { loa3_user.identity.mhv_correlation_id }
        let(:expected_mpi_value) { loa3_user.mpi_mhv_correlation_id }
        let(:validation_id) { 'MHV Correlation ID' }

        it_behaves_like 'identity-mpi id validation'
      end
    end

    context 'when creating an MHV account' do
      let(:user) { create(:user, :loa3, idme_uuid:) }
      let!(:user_verification) { create(:idme_user_verification, idme_uuid:) }
      let!(:user_account) { user_verification.user_account }
      let(:idme_uuid) { 'some-idme-uuid' }
      let(:enabled) { true }

      before do
        allow(MHV::AccountCreatorJob).to receive(:perform_async)
        allow(Flipper).to receive(:enabled?).with(:mhv_account_creation_after_login, user_account).and_return(enabled)
      end

      shared_examples 'a non-enqueued MHV::AccountCreatorJob' do
        it 'does not enqueue an MHV::AccountCreatorJob' do
          described_class.new(user).perform
          expect(MHV::AccountCreatorJob).not_to have_received(:perform_async)
        end
      end

      context 'when the user is LOA3' do
        context 'when :mhv_account_creation_after_login is enabled' do
          it 'enqueues an MHV::AccountCreatorJob' do
            described_class.new(user).perform
            expect(MHV::AccountCreatorJob).to have_received(:perform_async).with(user_verification.id)
          end
        end

        context 'when :mhv_account_creation_after_login is disabled' do
          let(:enabled) { false }

          it_behaves_like 'a non-enqueued MHV::AccountCreatorJob'
        end
      end

      context 'when the user is not LOA3' do
        let(:user) { create(:user) }

        it_behaves_like 'a non-enqueued MHV::AccountCreatorJob'
      end
    end
  end
end
