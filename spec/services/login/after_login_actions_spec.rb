# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Login::AfterLoginActions do
  describe '#perform' do
    context 'with a user that has evss access' do
      let(:user) { create(:evss_user) }

      it 'launches CreateUserAccountJob' do
        expect(EVSS::CreateUserAccountJob).to receive(:perform_async)
        described_class.new(user).perform
      end
    end

    context 'with a user that doesnt have evss access' do
      let(:user) { create(:user) }

      it 'shouldnt launch CreateUserAccountJob' do
        expect(EVSS::CreateUserAccountJob).not_to receive(:perform_async)
        described_class.new(user).perform
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
      let(:login_type) { 'myhealthevet' }

      before { allow_any_instance_of(UserIdentity).to receive(:sign_in).and_return(service_name: login_type) }

      context 'with non-existent login stats record' do
        it 'will create an account_login_stats record' do
          expect { described_class.new(user).perform }.to \
            change(AccountLoginStat, :count).by(1)
        end

        it 'will update the correct login stats column' do
          described_class.new(user).perform
          expect(AccountLoginStat.last.send("#{login_type}_at")).not_to be_nil
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
          login_type = 'idme'
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

    context 'user_verification creation' do
      subject { described_class.new(user).perform }

      let(:user) do
        create(:user,
               authn_context: authn_context,
               edipi: 'some-edipi',
               mhv_correlation_id: 'some-correlation-id',
               idme_uuid: 'some-idme-uuid',
               logingov_uuid: 'some-logingov-uuid')
      end
      let(:authn_context) { nil }

      context 'when user credential is mhv' do
        let(:authn_context) { 'myhealthevet' }
        let(:authn_identifier) { user.mhv_correlation_id }
        let(:authn_identifier_type) { :mhv_uuid }

        context 'and user_verification for user credential already exists' do
          before do
            UserVerification.create!(authn_identifier_type => authn_identifier, user_account: UserAccount.new(icn: nil))
          end

          it 'returns without creating user_verification' do
            expect { subject }.not_to change(UserVerification, :count)
          end
        end

        context 'and user_verification for user credential does not already exist' do
          it 'creates a new user_verification record' do
            expect { subject }.to change(UserVerification, :count)
          end

          it 'creates a user_account record attached to the user_verification record' do
            expect { subject }.to change(UserAccount, :count)
            expect(UserVerification.where(authn_identifier_type => authn_identifier).first.user_account).not_to be_nil
          end
        end
      end

      context 'when user credential is idme' do
        let(:authn_context) { LOA::IDME_LOA1_VETS }
        let(:authn_identifier) { user.idme_uuid }
        let(:authn_identifier_type) { :idme_uuid }

        context 'and user_verification for user credential already exists' do
          before do
            UserVerification.create!(authn_identifier_type => authn_identifier, user_account: UserAccount.new(icn: nil))
          end

          it 'returns without creating user_verification' do
            expect { subject }.not_to change(UserVerification, :count)
          end
        end

        context 'and user_verification for user credential does not already exist' do
          it 'creates a new user_verification record' do
            expect { subject }.to change(UserVerification, :count)
          end

          it 'creates a user_account record attached to the user_verification record' do
            expect { subject }.to change(UserAccount, :count)
            expect(UserVerification.where(authn_identifier_type => authn_identifier).first.user_account).not_to be_nil
          end
        end
      end

      context 'when user credential is dslogon' do
        let(:authn_context) { 'dslogon' }
        let(:authn_identifier) { user.identity.edipi }
        let(:authn_identifier_type) { :dslogon_uuid }

        context 'and user_verification for user credential already exists' do
          before do
            UserVerification.create!(authn_identifier_type => authn_identifier, user_account: UserAccount.new(icn: nil))
          end

          it 'returns without creating user_verification' do
            expect { subject }.not_to change(UserVerification, :count)
          end
        end

        context 'and user_verification for user credential does not already exist' do
          it 'creates a new user_verification record' do
            expect { subject }.to change(UserVerification, :count)
          end

          it 'creates a user_account record attached to the user_verification record' do
            expect { subject }.to change(UserAccount, :count)
            expect(UserVerification.where(authn_identifier_type => authn_identifier).first.user_account).not_to be_nil
          end
        end
      end

      context 'when user credential is logingov' do
        let(:authn_context) { IAL::LOGIN_GOV_IAL1 }
        let(:authn_identifier) { user.logingov_uuid }
        let(:authn_identifier_type) { :logingov_uuid }

        context 'and user_verification for user credential already exists' do
          before do
            UserVerification.create!(authn_identifier_type => authn_identifier, user_account: UserAccount.new(icn: nil))
          end

          it 'returns without creating user_verification' do
            expect { subject }.not_to change(UserVerification, :count)
          end
        end

        context 'and user_verification for user credential does not already exist' do
          it 'creates a new user_verification record' do
            expect { subject }.to change(UserVerification, :count)
          end

          it 'creates a user_account record attached to the user_verification record' do
            expect { subject }.to change(UserAccount, :count)
            expect(UserVerification.where(authn_identifier_type => authn_identifier).first.user_account).not_to be_nil
          end
        end
      end

      context 'when user credential is some other arbitrary value' do
        let(:login_value) { 'banana' }
        let(:user) { create(:user, sign_in: { service_name: login_value }) }
        let(:expected_log) do
          "[AfterLoginActions] Unknown or missing login_type for user:#{user.uuid}, login_type:#{login_value}"
        end

        it 'logs an unknown credential message' do
          expect(Rails.logger).to receive(:info).with(expected_log)
          subject
        end
      end

      context 'when an arbitrary error is raised' do
        let(:authn_context) { 'dslogon' }
        let(:expected_error_message) { 'Some expected error message' }
        let(:expected_error) { StandardError.new(expected_error_message) }
        let(:expected_log) do
          "[AfterLoginActions] UserVerification cannot be created, error=#{expected_error_message}"
        end

        before do
          allow(UserVerification).to receive(:find_by).and_raise(expected_error)
        end

        it 'rescues the error' do
          expect { subject }.not_to raise_exception
        end

        it 'logs a UserVerification cannot be created log' do
          expect(Rails.logger).to receive(:info).with(expected_log)
          subject
        end
      end
    end
  end
end
