# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Identity::AccountCreator, type: :model do
  let(:user) do
    OpenStruct.new({ idme_uuid:,
                     logingov_uuid:,
                     sec_id:,
                     edipi:,
                     icn: })
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
        expect(subject).to be_nil
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
        let(:account_ids) { [account_idme, account_logingov].map(&:id) }

        it 'does not create an account' do
          expect { subject }.not_to change(Account, :count)
        end

        context 'and set of matched accounts includes account with matching idme uuid' do
          let(:idme_uuid) { 'some-idme-uuid' }
          let(:logingov_uuid) { 'some-logingov-uuid' }
          let(:match_sec_id) { 'some-matched-sec-id' }

          let!(:account_sec) do
            create(:account,
                   edipi: account_edipi,
                   icn: account_icn,
                   sec_id: match_sec_id)
          end

          context 'and account attributes match relevant user attributes' do
            it 'returns existing account with matching idme_uuid, without changes' do
              expect(subject).to eq(account_idme)
            end
          end

          context 'and account attributes do not match relevant user attributes' do
            let(:icn) { 'kitty-icn' }
            let(:account_icn) { 'puppy-icn' }

            context 'and another account with current user logingov_uuid exists' do
              it 'deletes the account with conflicting logingov_uuid' do
                expect { subject }.to change(Account, :count).by(-1)
              end
            end

            it 'updates account with user attributes' do
              expect do
                subject
                account_idme.reload
              end.to change(account_idme, :icn).from(account_icn).to(icn)
            end

            it 'returns account with updated user attributes' do
              expect(subject.icn).to eq(icn)
            end
          end
        end

        context 'and set of matched accounts does not include account with matched idme uuid' do
          let(:idme_uuid) { nil }
          let(:account_idme_uuid) { 'banana-uuid' }
          let(:account_sec_id) { 'some-account-sec-id' }

          let!(:account_sec) do
            create(:account,
                   edipi: account_edipi,
                   icn: account_icn,
                   sec_id:)
          end

          context 'and set of matched accounts includes account with matching logingov uuid' do
            let(:logingov_uuid) { 'some-logingov-uuid' }

            context 'and account attributes match relevant user attributes' do
              it 'returns existing account with matching logingov_uuid, without changes' do
                expect(subject).to eq(account_logingov)
              end
            end

            context 'and account attributes do not match relevant user attributes' do
              let(:icn) { 'kitty-icn' }
              let(:account_icn) { 'puppy-icn' }

              it 'updates account with user attributes' do
                expect do
                  subject
                  account_logingov.reload
                end.to change(account_logingov, :icn).from(account_icn).to(icn)
              end

              it 'returns account with updated user attributes' do
                expect(subject.icn).to eq(icn)
              end
            end
          end

          context 'and set of matched accounts does not include account with matching logingov uuid' do
            let(:logingov_uuid) { nil }
            let(:account_logingov_uuid) { 'banana-logingov-uuid' }

            context 'and account attributes match relevant user attributes' do
              it 'returns existing account with matching sec_id, without changes' do
                expect(subject).to eq(account_sec)
              end
            end

            context 'and account attributes do not match relevant user attributes' do
              let(:icn) { 'kitty-icn' }
              let(:account_icn) { 'puppy-icn' }

              it 'updates account with user attributes' do
                expect do
                  subject
                  account_sec.reload
                end.to change(account_sec, :icn).from(account_icn).to(icn)
              end

              it 'returns account with updated user attributes' do
                expect(subject.icn).to eq(icn)
              end
            end
          end
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
          let(:user_attributes) { { idme_uuid: user.idme_uuid, icn: user.icn, sec_id: user.sec_id } }
          let(:account_attributes) { { idme_uuid: account.idme_uuid, icn: account.icn, sec_id: account.sec_id } }

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
