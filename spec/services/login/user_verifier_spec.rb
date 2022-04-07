# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Login::UserVerifier do
  describe '#perform' do
    subject { described_class.new(user).perform }

    let(:user) do
      OpenStruct.new(
        {
          uuid: uuid,
          identity: identity,
          mhv_correlation_id: mhv_correlation_id_identifier,
          idme_uuid: idme_uuid_identifier,
          logingov_uuid: logingov_uuid_identifier,
          icn: icn,
          user_verification_id: nil,
          user_account_uuid: nil
        }
      )
    end
    let(:uuid) { 'some-uuid' }
    let(:identity) do
      OpenStruct.new(
        {
          edipi: edipi_identifier,
          sign_in: { service_name: login_value }
        }
      )
    end
    let(:edipi_identifier) { 'some-edipi' }
    let(:mhv_correlation_id_identifier) { 'some-correlation-id' }
    let(:idme_uuid_identifier) { 'some-idme-uuid' }
    let(:logingov_uuid_identifier) { 'some-logingov-uuid' }

    let(:icn) { nil }
    let(:login_value) { nil }
    let(:time_freeze_time) { '10-10-2021' }

    before do
      Timecop.freeze(time_freeze_time)
    end

    after do
      Timecop.return
    end

    shared_examples 'user_verification with nil credential identifier' do
      let(:authn_identifier) { nil }
      let(:edipi_identifier) { authn_identifier }
      let(:mhv_correlation_id_identifier) { authn_identifier }
      let(:idme_uuid_identifier) { authn_identifier }
      let(:logingov_uuid_identifier) { authn_identifier }
      let(:expected_log) { "[Login::UserVerifier] Nil identifier for type=#{authn_identifier_type}" }
      let(:expected_error) { Login::Errors::UserVerificationNotCreatedError }

      context 'and there is not an alternate idme credential identifier' do
        it 'logs messages to rails logger and raises User Verification Not Created error' do
          expect(Rails.logger).to receive(:info).with(expected_log).ordered
          expect { subject }.to raise_exception(expected_error)
        end
      end

      context 'and there is an alternate idme credential identifier' do
        let(:type) { :idme_uuid }
        let(:expected_log_idme) do
          "[Login::UserVerifier] Attempting alternate type=#{type}  identifier=#{idme_uuid_identifier}"
        end
        let(:idme_uuid_identifier) { 'some-idme-uuid-identifier' }
        let!(:user_verification) do
          UserVerification.create!(type => idme_uuid_identifier,
                                   user_account: user_account)
        end
        let(:user_account) { UserAccount.new }

        it 'logs messages to rails logger' do
          expect(Rails.logger).to receive(:info).with(expected_log).ordered
          expect(Rails.logger).to receive(:info).with(expected_log_idme).ordered
          subject
        end

        it 'returns matched user_verification that matches idme uuid identifier' do
          expect(subject).to eq user_verification
        end
      end
    end

    shared_examples 'user_verification with defined credential identifier' do
      context 'and current user is verified, with an ICN value' do
        let(:icn) { 'some-icn' }

        context 'and user_verification for user credential already exists' do
          let(:user_account) { UserAccount.new(icn: user.icn) }
          let!(:user_verification) do
            UserVerification.create!(authn_identifier_type => authn_identifier,
                                     user_account: user_account)
          end

          it 'does not create a new user_verification' do
            expect { subject }.not_to change(UserVerification, :count)
          end

          context 'and user_account with the current user ICN exists' do
            let(:user_account) { UserAccount.new(icn: user.icn) }

            context 'and this user account is already associated with the user_verification' do
              it 'does not change user_verification user_account associations' do
                expect do
                  subject
                  user_verification.reload
                end.not_to change(user_verification, :user_account)
              end

              it 'returns the existing user_verification' do
                expect(subject).to eq(user_verification)
              end
            end

            context 'and this user account is not already associated with the user_verification' do
              let(:user_account) { UserAccount.new(icn: 'some-other-icn') }
              let(:other_user_account) { UserAccount.new(icn: user.icn) }
              let(:expected_log_message) do
                "[Login::UserVerifier] Deprecating UserAccount id=#{user_account.id}, " \
                  "Updating UserVerification id=#{user_verification.id} with " \
                  "UserAccount id=#{other_user_account.id}"
              end
              let(:expected_verified_at_time) { Time.zone.now }

              before do
                UserVerification.create!(authn_identifier_type => 'some-other-authn-identifier',
                                         user_account: other_user_account)
              end

              it 'sets the user_verification verified_at time to now' do
                expect do
                  subject
                  user_verification.reload
                end.to change(user_verification, :verified_at).from(nil).to(expected_verified_at_time)
              end

              it 'changes user_verification user_account associations' do
                expect do
                  subject
                  user_verification.reload
                end.to change(user_verification, :user_account).from(user_account).to(other_user_account)
              end

              it 'creates a deprecated user account' do
                expect { subject }.to change(DeprecatedUserAccount, :count).by(1)
              end

              it 'writes a log to rails logger' do
                expect(Rails.logger).to receive(:info).with(expected_log_message)
                subject
              end

              it 'sets the deprecated user account to the initial user_verification user_account' do
                subject
                deprecated_account = DeprecatedUserAccount.find_by(user_verification: user_verification).user_account
                expect(deprecated_account).to eq(user_account)
              end

              it 'returns the existing user_verification' do
                expect(subject).to eq(user_verification)
              end
            end
          end

          context 'and user_account with the current user ICN does not exist' do
            let(:user_account) { UserAccount.new(icn: nil) }
            let(:expected_verified_at_time) { Time.zone.now }

            it 'updates the associated user_account with the current user ICN' do
              expect do
                subject
                user_account.reload
              end.to change(user_account, :icn).from(nil).to(user.icn)
            end

            it 'sets the user_verification verified_at time to now' do
              expect do
                subject
                user_verification.reload
              end.to change(user_verification, :verified_at).from(nil).to(expected_verified_at_time)
            end

            it 'returns the existing user_verification' do
              expect(subject).to eq(user_verification)
            end
          end
        end

        context 'and user_verification for user credential does not already exist' do
          let(:expected_verified_at_time) { Time.zone.now }

          it 'creates a new user_verification record' do
            expect { subject }.to change(UserVerification, :count)
          end

          it 'sets the user_verification verified_at time to now' do
            subject
            user_verification = UserVerification.where(authn_identifier_type => authn_identifier).first
            expect(user_verification.verified_at).to eq(expected_verified_at_time)
          end

          context 'and user_account matching icn does not already exist' do
            it 'sets the current user ICN on the user_account record' do
              subject
              account_icn = UserVerification.where(authn_identifier_type => authn_identifier).first.user_account.icn
              expect(account_icn).to eq user.icn
            end

            it 'creates a user_account record attached to the user_verification record' do
              expect { subject }.to change(UserAccount, :count)
              user_account = UserVerification.where(authn_identifier_type => authn_identifier).first.user_account
              expect(user_account).not_to be_nil
            end

            it 'returns created user_verification' do
              expect(subject).to eq(UserVerification.last)
            end
          end

          context 'and user_account matching icn already exists' do
            let!(:existing_user_account) { UserAccount.create!(icn: icn) }

            it 'does not create a new user_account record' do
              expect { subject }.not_to change(UserAccount, :count)
            end

            it 'attaches the existing user_account to the new user_verification record' do
              subject
              account_icn = UserVerification.where(authn_identifier_type => authn_identifier).first.user_account
              expect(account_icn).to eq existing_user_account
            end

            it 'returns created user_verification' do
              expect(subject).to eq(UserVerification.last)
            end
          end
        end
      end

      context 'and current user is not verified, without an ICN value' do
        let(:icn) { nil }

        context 'and user_verification for user credential already exists' do
          let!(:user_verification) do
            UserVerification.create!(authn_identifier_type => authn_identifier,
                                     user_account: UserAccount.new(icn: nil))
          end

          it 'does not create user_verification' do
            expect { subject }.not_to change(UserVerification, :count)
          end

          it 'returns existing user_verification' do
            expect(subject).to eq(user_verification)
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

          it 'returns created user_verification' do
            expect(subject).to eq(UserVerification.last)
          end
        end
      end
    end

    context 'when user credential is mhv' do
      let(:login_value) { 'myhealthevet' }
      let(:authn_identifier) { user.mhv_correlation_id }
      let(:authn_identifier_type) { :mhv_uuid }

      it_behaves_like 'user_verification with nil credential identifier'
      it_behaves_like 'user_verification with defined credential identifier'
    end

    context 'when user credential is idme' do
      let(:login_value) { 'idme' }
      let(:authn_identifier) { user.idme_uuid }
      let(:authn_identifier_type) { :idme_uuid }

      context 'when credential identifier is nil' do
        let(:authn_identifier) { nil }
        let(:edipi_identifier) { authn_identifier }
        let(:mhv_correlation_id_identifier) { authn_identifier }
        let(:idme_uuid_identifier) { authn_identifier }
        let(:logingov_uuid_identifier) { authn_identifier }
        let(:expected_log) { "[Login::UserVerifier] Nil identifier for type=#{authn_identifier_type}" }
        let(:expected_error) { Login::Errors::UserVerificationNotCreatedError }

        it 'logs messages to rails logger and raises User Verification Not Created error' do
          expect(Rails.logger).to receive(:info).with(expected_log).ordered
          expect { subject }.to raise_exception(expected_error)
        end
      end

      it_behaves_like 'user_verification with defined credential identifier'
    end

    context 'when user credential is dslogon' do
      let(:login_value) { 'dslogon' }
      let(:authn_identifier) { user.identity.edipi }
      let(:authn_identifier_type) { :dslogon_uuid }

      it_behaves_like 'user_verification with nil credential identifier'
      it_behaves_like 'user_verification with defined credential identifier'
    end

    context 'when user credential is logingov' do
      let(:login_value) { 'logingov' }
      let(:authn_identifier) { user.logingov_uuid }
      let(:authn_identifier_type) { :logingov_uuid }

      it_behaves_like 'user_verification with nil credential identifier'
      it_behaves_like 'user_verification with defined credential identifier'
    end

    context 'when user credential is some other arbitrary value' do
      let(:login_value) { 'banana' }
      let(:expected_log) do
        "[Login::UserVerifier] Unknown or missing login_type for user=#{user.uuid}, login_type=#{login_value}"
      end
      let(:expected_error) { Login::Errors::UnknownLoginTypeError }

      it 'logs messages to rails logger and raises Unknown Login Type error' do
        expect(Rails.logger).to receive(:info).with(expected_log).ordered
        expect { subject }.to raise_exception(expected_error)
      end
    end
  end
end
