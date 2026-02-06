# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Login::UserVerifier do
  describe '#perform' do
    subject do
      described_class.new(login_type:,
                          auth_broker:,
                          mhv_uuid:,
                          idme_uuid:,
                          logingov_uuid:,
                          icn:,
                          credential_attributes_digest:).perform
    end

    let(:auth_broker) { 'some-auth-broker' }
    let(:mhv_uuid) { 'some-credential-uuid' }
    let(:idme_uuid) { 'some-idme-uuid' }
    let(:logingov_uuid) { 'some-logingov-uuid' }
    let(:locked) { false }
    let(:icn) { nil }
    let(:login_type) { nil }
    let(:credential_attributes_digest) { 'some-digest' }

    let(:time_freeze_time) { '10-10-2021' }

    before do
      Timecop.freeze(time_freeze_time)
    end

    after do
      Timecop.return
    end

    shared_examples 'user_verification with nil credential identifier' do
      let(:authn_identifier) { nil }
      let(:mhv_uuid) { authn_identifier }
      let(:idme_uuid) { authn_identifier }
      let(:logingov_uuid) { authn_identifier }
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
          "[Login::UserVerifier] Attempting alternate type=#{type} identifier=#{idme_uuid}"
        end
        let(:idme_uuid) { 'some-idme-uuid-identifier' }
        let!(:user_verification) do
          UserVerification.create!(type => idme_uuid,
                                   backing_idme_uuid:,
                                   user_account:,
                                   locked:)
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
        let(:expected_log) do
          '[Login::UserVerifier] New VA.gov user, ' \
            "type=#{login_type}, broker=#{auth_broker}, identifier=#{authn_identifier}, locked=#{locked}"
        end

        context 'and user_verification for user credential already exists' do
          let(:user_account) { UserAccount.new(icn:) }
          let!(:user_verification) do
            UserVerification.create!(authn_identifier_type => authn_identifier,
                                     user_account:,
                                     backing_idme_uuid:,
                                     verified_at:,
                                     locked:,
                                     credential_attributes_digest:)
          end
          let(:verified_at) { 1.day.ago }

          it 'does not make new user log to rails logger' do
            expect(Rails.logger).not_to receive(:info).with(expected_log, { icn: })
            subject
          end

          it 'does not create a new user_verification' do
            expect { subject }.not_to change(UserVerification, :count)
          end

          context 'and determined backing idme uuid is different than existing backing idme uuid' do
            let(:old_backing_idme_uuid) { 'some-old-backing-idme-uuid' }
            let!(:user_verification) do
              UserVerification.create!(authn_identifier_type => authn_identifier,
                                       user_account:,
                                       backing_idme_uuid: old_backing_idme_uuid,
                                       verified_at:)
            end

            it 'updates user verification with the new determined backing idme uuid' do
              expect(subject.backing_idme_uuid).to eq(backing_idme_uuid)
            end
          end

          context 'and the credential_attributes_digest is different' do
            let!(:user_verification) do
              UserVerification.create!(authn_identifier_type => authn_identifier,
                                       user_account:,
                                       backing_idme_uuid:,
                                       verified_at:,
                                       locked:,
                                       credential_attributes_digest: 'some-old-digest')
            end

            it 'updates the user verification with the new credential_attributes_digest' do
              expect do
                subject
                user_verification.reload
              end.to change(user_verification,
                            :credential_attributes_digest).from('some-old-digest').to(credential_attributes_digest)
            end
          end

          context 'and the credential_attributes_digest is the same' do
            let(:credential_attributes_digest) { 'some-digest' }

            it 'does not update the user verification credential_attributes_digest' do
              expect do
                subject
                user_verification.reload
              end.not_to change(user_verification, :credential_attributes_digest)
            end
          end

          context 'and user_account with the current user ICN exists' do
            let(:user_account) { UserAccount.new(icn:) }

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
              let(:other_user_account) { UserAccount.new(icn:) }

              context 'and the current user_verification is not verified' do
                let(:user_account) { UserAccount.new(icn: nil) }
                let(:verified_at) { nil }
                let(:expected_log_message) do
                  "[Login::UserVerifier] Deprecating UserAccount id=#{user_account.id}, " \
                    "Updating UserVerification id=#{user_verification.id} with " \
                    "UserAccount id=#{other_user_account.id}"
                end
                let(:expected_verified_at_time) { Time.zone.now }

                before do
                  UserVerification.create!(authn_identifier_type => 'some-other-authn-identifier',
                                           backing_idme_uuid:,
                                           user_account: other_user_account)
                end

                it 'sets the user_verification verified_at time to now' do
                  expect do
                    subject
                    user_verification.reload
                  end.to change(user_verification, :verified_at).from(verified_at).to(expected_verified_at_time)
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
                  deprecated_account = DeprecatedUserAccount.find_by(user_verification:).user_account
                  expect(deprecated_account).to eq(user_account)
                end

                it 'returns the existing user_verification' do
                  expect(subject).to eq(user_verification)
                end
              end

              context 'and the current user_verification is verified' do
                let(:user_account) { UserAccount.new(icn: 'some-other-icn') }
                let(:verified_at) { 1.day.ago }
                let(:expected_message) do
                  "[Login::UserVerifier] User Account Mismatch for UserVerification id=#{user_verification.id}, " \
                    "UserAccount id=#{user_account.id}, icn=#{user_account.icn}, " \
                    "conflicts with UserAccount id=#{other_user_account.id} icn=#{other_user_account.icn} " \
                    "Setting UserVerification id=#{user_verification.id} association to " \
                    "UserAccount id=#{other_user_account.id}"
                end

                before do
                  UserVerification.create!(authn_identifier_type => 'some-other-authn-identifier',
                                           backing_idme_uuid:,
                                           user_account: other_user_account)
                end

                it 'logs a user account mismatch message' do
                  expect(Rails.logger).to receive(:info).with(expected_message)
                  subject
                end

                it 'updates the user verification with the existing user account' do
                  expect(subject.user_account).to eq(other_user_account)
                end

                it 'updates the credential_attributes_digest if different' do
                  expect(subject.credential_attributes_digest).to eq(credential_attributes_digest)
                end
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
              end.to change(user_account, :icn).from(nil).to(icn)
            end

            it 'sets the user_verification verified_at time to now' do
              expect do
                subject
                user_verification.reload
              end.to change(user_verification, :verified_at).from(verified_at).to(expected_verified_at_time)
            end

            it 'returns the existing user_verification' do
              expect(subject).to eq(user_verification)
            end
          end
        end

        context 'and user_verification for user credential does not already exist' do
          let(:expected_verified_at_time) { Time.zone.now }
          let(:expected_log) do
            '[Login::UserVerifier] New VA.gov user, ' \
              "type=#{login_type}, broker=#{auth_broker}, identifier=#{authn_identifier}, locked=#{locked}"
          end

          it 'makes a new user log to rails logger' do
            expect(Rails.logger).to receive(:info).with(expected_log, { icn: })
            subject
          end

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
              expect(account_icn).to eq icn
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
            let!(:existing_user_account) { UserAccount.create(icn:) }

            context 'and a linked user verification with the same CSP type exists' do
              let!(:linked_user_verification) do
                create(linked_user_verification_type, user_account: existing_user_account, locked:)
              end

              context 'and the linked user verification is locked' do
                let(:locked) { true }

                it 'creates a locked UserVerification object and logs the event' do
                  expect(Rails.logger).to receive(:info).with(expected_log, { icn: })
                  expect(subject.locked).to be(true)
                end
              end

              context 'and the linked user verification is not locked' do
                it 'creates an unlocked UserVerification object' do
                  expect(subject.locked).to be(false)
                end
              end
            end

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
        let(:expected_log) do
          '[Login::UserVerifier] New VA.gov user, ' \
            "type=#{login_type}, broker=#{auth_broker}, identifier=#{authn_identifier}, locked=#{locked}"
        end

        context 'and user_verification for user credential already exists' do
          let!(:user_verification) do
            UserVerification.create!(authn_identifier_type => authn_identifier,
                                     backing_idme_uuid:,
                                     user_account: UserAccount.new(icn: nil))
          end

          it 'does not make new user log to rails logger' do
            expect(Rails.logger).not_to receive(:info).with(expected_log, { icn: })
            subject
          end

          it 'does not create user_verification' do
            expect { subject }.not_to change(UserVerification, :count)
          end

          context 'and determined backing idme uuid is different than existing backing idme uuid' do
            let(:old_backing_idme_uuid) { 'some-old-backing-idme-uuid' }
            let!(:user_verification) do
              UserVerification.create!(authn_identifier_type => authn_identifier,
                                       user_account: UserAccount.new(icn: nil),
                                       backing_idme_uuid: old_backing_idme_uuid)
            end

            it 'updates user verification with the new determined backing idme uuid' do
              expect(subject.backing_idme_uuid).to eq(backing_idme_uuid)
            end
          end

          it 'returns existing user_verification' do
            expect(subject).to eq(user_verification)
          end

          context 'and the credential_attributes_digest is different' do
            let(:credential_attributes_digest) { 'some-new-digest' }

            it 'does not update the user verification with the new credential_attributes_digest' do
              expect do
                subject
                user_verification.reload
              end.not_to change(user_verification, :credential_attributes_digest)
            end
          end
        end

        context 'and user_verification for user credential does not already exist' do
          it 'makes a new user log to rails logger' do
            expect(Rails.logger).to receive(:info).with(expected_log, { icn: })
            subject
          end

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

          context 'and the credential_attributes_digest is different' do
            let(:credential_attributes_digest) { 'some-new-digest' }

            it 'does not create the user verification with the new credential_attributes_digest' do
              subject
              user_verification = UserVerification.where(authn_identifier_type => authn_identifier).first
              expect(user_verification.credential_attributes_digest).to be_nil
            end
          end
        end
      end
    end

    context 'when user credential is mhv' do
      let(:login_type) { SignIn::Constants::Auth::MHV }
      let(:authn_identifier) { mhv_uuid }
      let(:authn_identifier_type) { :mhv_uuid }
      let(:backing_idme_uuid) { idme_uuid }
      let(:linked_user_verification_type) { :mhv_user_verification }

      it_behaves_like 'user_verification with nil credential identifier'
      it_behaves_like 'user_verification with defined credential identifier'
    end

    context 'when user credential is idme' do
      let(:login_type) { SignIn::Constants::Auth::IDME }
      let(:authn_identifier) { idme_uuid }
      let(:authn_identifier_type) { :idme_uuid }
      let(:backing_idme_uuid) { nil }
      let(:linked_user_verification_type) { :idme_user_verification }

      context 'when credential identifier is nil' do
        let(:authn_identifier) { nil }
        let(:mhv_uuid) { authn_identifier }
        let(:idme_uuid) { authn_identifier }
        let(:logingov_uuid) { authn_identifier }
        let(:expected_log) { "[Login::UserVerifier] Nil identifier for type=#{authn_identifier_type}" }
        let(:expected_error) { Login::Errors::UserVerificationNotCreatedError }

        it 'logs messages to rails logger and raises User Verification Not Created error' do
          expect(Rails.logger).to receive(:info).with(expected_log).ordered
          expect { subject }.to raise_exception(expected_error)
        end
      end

      it_behaves_like 'user_verification with defined credential identifier'
    end

    context 'when user credential is logingov' do
      let(:login_type) { SignIn::Constants::Auth::LOGINGOV }
      let(:authn_identifier) { logingov_uuid }
      let(:authn_identifier_type) { :logingov_uuid }
      let(:backing_idme_uuid) { nil }
      let(:linked_user_verification_type) { :logingov_user_verification }

      it_behaves_like 'user_verification with nil credential identifier'
      it_behaves_like 'user_verification with defined credential identifier'
    end
  end
end
