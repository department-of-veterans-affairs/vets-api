# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe Login::AfterLoginActions do
  describe '#perform' do
    before do
      Sidekiq::Worker.clear_all
    end

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
        it 'will create an account_login_stats record' do
          expect { described_class.new(user).perform }.to \
            change(AccountLoginStat, :count).by(1)
        end

        it 'will update the correct login stats column' do
          described_class.new(user).perform
          expect(AccountLoginStat.last.send("#{login_type_stat}_at")).not_to be_nil
        end

        it 'will update the current_verification column' do
          described_class.new(user).perform
          expect(AccountLoginStat.last.current_verification).to eq('loa1')
        end

        it 'will not create a record if login_type is not valid' do
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

        it 'will not create another record' do
          expect { described_class.new(user).perform }.not_to \
            change(AccountLoginStat, :count)
        end

        it 'will overwrite existing value if login type was seen previously' do
          stat = AccountLoginStat.last

          expect do
            described_class.new(user).perform
            stat.reload
          end.to change(stat, :myhealthevet_at)
        end

        it 'will set new value in blank login column' do
          login_type = SAML::User::IDME_CSID
          allow_any_instance_of(UserIdentity).to receive(:sign_in).and_return(service_name: login_type)
          stat = AccountLoginStat.last

          expect do
            described_class.new(user).perform
            stat.reload
          end.not_to change(stat, :myhealthevet_at)

          expect(stat.idme_at).not_to be_blank
        end

        it 'will trigger sentry error if update fails' do
          allow_any_instance_of(AccountLoginStat).to receive(:update!).and_raise('Failure!')
          expect_any_instance_of(described_class).to receive(:log_error)
          described_class.new(user).perform
        end
      end

      context 'with a non-existant account' do
        before { allow_any_instance_of(User).to receive(:account).and_return(nil) }

        it 'will trigger sentry error message' do
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

    context 'AcceptableVerifiedCredentialAdoptionService' do
      let(:user) { create(:user, :dslogon) }
      let(:user_verification) { create(:dslogon_user_verification, dslogon_uuid: user.edipi) }
      let(:user_account) { user_verification.user_account }
      let!(:user_acceptable_verified_credential) do
        create(:user_acceptable_verified_credential, :with_avc, user_account:)
      end

      context 'when When Flipper reactivation_experiment_initial_gate is enabled' do
        it 'sends an email' do
          expect { described_class.new(user).perform }.to change(VANotify::EmailJob.jobs, :size).by(1)
        end
      end

      context 'When Flipper reactivation_experiment_initial_gate is disabled' do
        before do
          Flipper.disable(:reactivation_experiment_initial_gate)
        end

        it 'does not send an email' do
          expect { described_class.new(user).perform }.not_to change(VANotify::EmailJob.jobs, :size)
        end
      end
    end

    context 'enqueue MHV::PhrUpdateJob' do
      let(:user) { create(:user) }
      let(:icn) { '1000000000V000000' }
      let(:mhv_correlation_id) { '12345' }

      before do
        allow(user).to receive(:icn).and_return(icn)
        allow(user).to receive(:mhv_correlation_id).and_return(mhv_correlation_id)
      end

      it 'enqueues the job with correct parameters' do
        expect do
          described_class.new(user).perform
        end.to change(Sidekiq::Queues['default'], :size).by(1)

        enqueued_job = Sidekiq::Queues['default'].last
        expect(enqueued_job['class']).to eq 'MHV::PhrUpdateJob'
        expect(enqueued_job['args']).to eq [icn, mhv_correlation_id]
      end
    end
  end
end
