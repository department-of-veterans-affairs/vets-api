# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Identity::AccountCreator, type: :model do
  let(:user) do
    OpenStruct.new({ idme_uuid: idme_uuid,
                     logingov_uuid: logingov_uuid,
                     sec_id: sec_id,
                     edipi: edipi,
                     icn: icn })
  end
  let(:idme_uuid) { nil }
  let(:logingov_uuid) { nil }
  let(:sec_id) { nil }
  let(:edipi) { nil }
  let(:icn) { nil }

  describe '#call' do
    subject { described_class.new(user).call }

    context 'when user does not have an idme_uuid, sec_id, or logingov_uuid' do
      it 'returns nil' do
        expect(subject).to be nil
      end
    end

    context 'when user has relevant identifiers' do
      let(:idme_uuid) { 'some-idme-uuid' }
      let(:sec_id) { 'some-sec-id' }

      context 'and multiple accounts match the given identifiers' do
        let(:account_idme_uuid) { idme_uuid }
        let(:account_logingov_uuid) { logingov_uuid }
        let(:account_sec_id) { sec_id }
        let(:account_edipi) { edipi }
        let(:account_icn) { icn }
        let(:account_creator_instance) { described_class.new(user) }
        let!(:account_idme) do
          create(:account,
                 idme_uuid: account_idme_uuid,
                 edipi: account_edipi,
                 icn: account_icn,
                 sec_id: account_sec_id)
        end
        let!(:account_logingov) do
          create(:account,
                 logingov_uuid: account_logingov_uuid,
                 edipi: account_edipi,
                 icn: account_icn,
                 sec_id: account_sec_id)
        end
        let(:expected_sentry_message) { 'multiple Account records with matching ids' }
        let(:expected_sentry_message_data) do
          [account_idme, account_logingov].map { |a| "Account:#{a.id}" }
        end

        it 'logs a message to sentry' do
          expect(account_creator_instance).to receive(:log_message_to_sentry).with(expected_sentry_message,
                                                                                   'warning',
                                                                                   expected_sentry_message_data)
          account_creator_instance.call
        end

        it 'returns the account with matching idme uuid' do
          expect(subject).to eq(account_idme)
        end
      end

      context 'and a single account matches the given identifiers' do
        let(:account_idme_uuid) { idme_uuid }
        let(:account_logingov_uuid) { logingov_uuid }
        let(:account_sec_id) { sec_id }
        let(:account_edipi) { edipi }
        let(:account_icn) { icn }
        let!(:account) do
          create(:account,
                 idme_uuid: account_idme_uuid,
                 logingov_uuid: account_logingov_uuid,
                 sec_id: account_sec_id,
                 edipi: account_edipi,
                 icn: account_icn)
        end

        it 'does not create an account' do
          expect { subject }.not_to change(Account, :count)
        end

        context 'and account attributes match relevant user attributes' do
          it 'returns existing account without changes' do
            expect(subject).to eq(account)
          end
        end

        context 'and account attributes do not match relevant user attributes' do
          let(:icn) { 'kitty-icn' }
          let(:account_icn) { 'puppy-icn' }
          let(:account_creator_instance) { described_class.new(user) }
          let(:expected_sentry_message) { 'Account record does not match User' }
          let(:user_attributes) { { idme_uuid: user.idme_uuid, icn: user.icn, sec_id: user.sec_id } }
          let(:account_attributes) { { idme_uuid: account.idme_uuid, icn: account.icn, sec_id: account.sec_id } }
          let(:expected_sentry_diff) { { account: account_attributes, user: user_attributes } }

          it 'logs a message to sentry' do
            expect(account_creator_instance).to receive(:log_message_to_sentry).with(expected_sentry_message,
                                                                                     'warning',
                                                                                     expected_sentry_diff)
            account_creator_instance.call
          end

          it 'updates account with user attributes' do
            expect do
              subject
              account.reload
            end.to change(account, :icn).from(account_icn).to(icn)
          end

          it 'returns account with updated user attributes' do
            expect(subject.icn).to eq(icn)
          end
        end
      end

      context 'and no account matches the given identifiers' do
        it 'creates a new account with the given attributes' do
          expect { subject }.to change(Account, :count).by(1)
        end

        it 'returns the newly created account' do
          account = subject

          expect(account.idme_uuid).to eq(idme_uuid)
          expect(account.class).to be(Account)
        end
      end
    end
  end
end
