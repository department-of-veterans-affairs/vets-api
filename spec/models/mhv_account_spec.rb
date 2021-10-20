# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MHVAccount, type: :model do
  let(:mvi_profile) do
    build(:mvi_profile,
          icn: '1012667122V019349',
          given_names: %w[Hector],
          family_name: 'Allen',
          suffix: nil,
          gender: 'M',
          birth_date: '1932-02-05',
          ssn: '796126859',
          mhv_ids: mhv_ids,
          active_mhv_ids: active_mhv_ids,
          vha_facility_ids: vha_facility_ids,
          home_phone: nil,
          address: mvi_profile_address)
  end

  let(:mvi_profile_address) do
    build(:mvi_profile_address,
          street: '20140624',
          city: 'Houston',
          state: 'TX',
          country: 'USA',
          postal_code: '77040')
  end

  let(:user) do
    create(:user,
           loa: user_loa,
           ssn: user_ssn,
           first_name: mvi_profile.given_names.first,
           last_name: mvi_profile.family_name,
           gender: mvi_profile.gender,
           birth_date: mvi_profile.birth_date,
           email: 'vets.gov.user+0@gmail.com')
  end

  let(:user_loa) { { current: LOA::THREE, highest: LOA::THREE } }
  let(:user_ssn) { mvi_profile.ssn }
  let(:mhv_ids) { [] }
  let(:active_mhv_ids) { mhv_ids }
  let(:vha_facility_ids) { ['450'] }

  before do
    stub_mpi(mvi_profile)
  end

  around do |example|
    with_settings(Settings.mhv, facility_range: [[358, 718], [720, 758]]) do
      example.run
    end
  end

  describe 'event' do
    subject { user.mhv_account }

    context 'check_eligibility' do
      context 'user not loa3' do
        let(:user_loa) { { current: LOA::ONE, highest: LOA::ONE } }

        it 'needs_identity_verification' do
          expect(subject.account_state).to eq('needs_identity_verification')
          expect(subject).not_to be_creatable
        end
      end

      context 'user ssn mismatch' do
        let(:user_ssn) { '123456789' }

        it 'needs_ssn_resolution' do
          expect(subject.account_state).to eq('needs_ssn_resolution')
          expect(subject).not_to be_creatable
        end
      end

      context 'user not a va patient' do
        let(:vha_facility_ids) { ['999'] }

        it 'needs_va_patient' do
          expect(subject.account_state).to eq('needs_va_patient')
          expect(subject).not_to be_creatable
        end
      end

      context 'user has previously deactivated mhv ids' do
        let(:mhv_ids) { %w[14221465 14221466] }
        let(:active_mhv_ids) { %w[14221466] }

        it 'has_deactivated_mhv_ids' do
          expect(subject.account_state).to eq('has_deactivated_mhv_ids')
          expect(subject).not_to be_creatable
        end
      end

      context 'user has multiple active mhv ids' do
        let(:mhv_ids) { %w[14221465 14221466] }
        let(:active_mhv_ids) { mhv_ids }

        it 'has_multiple_active_mhv_ids' do
          expect(subject.account_state).to eq('has_multiple_active_mhv_ids')
          expect(subject).not_to be_creatable
        end
      end

      context 'user has not accepted terms and conditions' do
        let(:mhv_ids) { %w[14221465] }

        it 'needs_terms_acceptance' do
          expect(subject.account_state).to eq('needs_terms_acceptance')
          expect(subject).not_to be_creatable
        end
      end
    end

    describe '#track_state' do
      let(:tracker_id) { user.uuid.to_s + user.mhv_correlation_id.to_s }

      it 'creates redis entry' do
        subject.creatable?
        expect(MHVAccountIneligible.find(tracker_id)).to be_truthy
      end

      it 'updates an existing redis entry when the account_state is a mismatch' do
        subject.creatable?
        tracker = MHVAccountIneligible.find(tracker_id)
        tracker.update(account_state: 'fake')
        subject.send(:setup)
        updated_tracker = MHVAccountIneligible.find(tracker_id)
        expect(updated_tracker.account_state).not_to eq(tracker.account_state)
      end

      it 'does not update an existing redis entry when the account_state is a match' do
        subject.creatable?
        tracker = MHVAccountIneligible.find(tracker_id)
        tracker.update(icn: 'fake')
        subject.send(:setup)
        updated_tracker = MHVAccountIneligible.find(tracker_id)
        expect(updated_tracker.icn).to eq(tracker.icn)
      end

      it 'can have multiple trackers for the same uuid and icn' do
        attrs = { uuid: user.uuid, account_state: 'whatever',
                  mhv_correlation_id: 'different_id', icn: user.icn,
                  tracker_id: (user.uuid.to_s + 'different_id') }
        MHVAccountIneligible.create(attrs)

        subject.creatable?
        tracker = MHVAccountIneligible.find(tracker_id)
        expect(tracker).to be_truthy
        expect(tracker.mhv_correlation_id).to eq(user.mhv_correlation_id)
        expect(tracker.account_state).to eq(:needs_terms_acceptance)
        expect(tracker.uuid).to eq(user.uuid)

        tracker = MHVAccountIneligible.find(user.uuid.to_s + 'different_id')
        expect(tracker).to be_truthy
        expect(tracker.mhv_correlation_id).to eq('different_id')
        expect(tracker.account_state).to eq('whatever')
        expect(tracker.uuid).to eq(user.uuid)
      end
    end

    context 'check_account_state' do
      context 'with terms accepted' do
        let(:terms) { create(:terms_and_conditions, latest: true, name: described_class::TERMS_AND_CONDITIONS_NAME) }

        before { create(:terms_and_conditions_acceptance, terms_and_conditions: terms, user_uuid: user.uuid) }

        context 'without an existing account' do
          context 'nothing has been persisted and no mhv_id' do
            it 'has no_account' do
              expect(subject.account_state).to eq('no_account')
              expect(subject).to be_creatable
              expect(subject).to be_terms_and_conditions_accepted
            end
          end
        end

        context 'with existing account' do
          let(:mhv_ids) { %w[14221465] }

          context 'nothing has been persisted with current mhv id' do
            before do
              allow_any_instance_of(MHVAccountTypeService)
                .to receive(:mhv_account_type).and_return(account_type)
            end

            context 'account level basic' do
              let(:account_type) { 'Basic' }

              it 'has existing' do
                expect(subject.account_state).to eq('existing')
                expect(subject).not_to be_creatable
                expect(subject).to be_upgradable
                expect(subject).to be_terms_and_conditions_accepted
              end
            end

            context 'account level advanced' do
              let(:account_type) { 'Advanced' }

              it 'has existing' do
                expect(subject.account_state).to eq('existing')
                expect(subject).not_to be_creatable
                expect(subject).to be_upgradable
                expect(subject).to be_terms_and_conditions_accepted
              end
            end

            context 'account level premium' do
              let(:account_type) { 'Premium' }

              it 'has existing' do
                expect(subject.account_state).to eq('existing')
                expect(subject).not_to be_creatable
                expect(subject).not_to be_upgradable
                expect(subject).to be_terms_and_conditions_accepted
              end
            end

            context 'account level unknown' do
              let(:account_type) { 'Unknown' }

              it 'has existing' do
                expect(subject.account_state).to eq('existing')
                expect(subject).not_to be_creatable
                expect(subject).not_to be_upgradable
                expect(subject).to be_terms_and_conditions_accepted
              end
            end

            context 'account level unknown' do
              let(:account_type) { 'Error' }

              it 'has existing' do
                expect(subject.account_state).to eq('existing')
                expect(subject).not_to be_creatable
                expect(subject).not_to be_upgradable
                expect(subject).to be_terms_and_conditions_accepted
              end
            end
          end

          context 'previously upgraded' do
            before do
              create(:mhv_account, :upgraded, user_uuid: user.uuid, mhv_correlation_id: user.mhv_correlation_id)
            end

            it 'has upgraded' do
              expect(subject.account_state).to eq('upgraded')
              expect(subject.changes[:account_state]).to be_nil
              expect(subject).not_to be_creatable
              expect(subject).not_to be_upgradable
              expect(subject).to be_terms_and_conditions_accepted
            end
          end

          context 'previously registered but somehow upgraded because of account level' do
            before do
              create(:mhv_account, :upgraded, upgraded_at: nil, user_uuid: user.uuid,
                                              mhv_correlation_id: user.mhv_correlation_id)
            end

            it 'has upgraded, with account level Premium, but it is treated as upgraded therefore not upgradable' do
              expect_any_instance_of(User).to receive(:mhv_account_type).once.and_return('Premium')
              expect(subject.account_state).to eq('upgraded')
              expect(subject.changes[:account_state]).to be_nil
              expect(subject).not_to be_creatable
              expect(subject).not_to be_upgradable
              expect(subject).to be_terms_and_conditions_accepted
            end

            it 'has upgraded, with account level Error, but it is treated as upgraded therefore not upgradable' do
              expect_any_instance_of(User).to receive(:mhv_account_type).once.and_return('Error')
              expect(subject.account_state).to eq('upgraded')
              expect(subject.changes[:account_state]).to be_nil
              expect(subject).not_to be_creatable
              expect(subject).not_to be_upgradable
              expect(subject).to be_terms_and_conditions_accepted
            end
          end

          context 'previously registered' do
            before do
              create(:mhv_account, :registered, user_uuid: user.uuid, mhv_correlation_id: user.mhv_correlation_id)
            end

            it 'has registered, upgradable with account level basic' do
              expect_any_instance_of(User).to receive(:mhv_account_type).twice.and_return('Basic')
              expect(subject.account_state).to eq('registered')
              expect(subject.changes).to be_empty
              expect(subject).not_to be_creatable
              expect(subject).to be_upgradable
              expect(subject).to be_terms_and_conditions_accepted
            end

            it 'has registered, upgradable with account level advanced' do
              expect_any_instance_of(User).to receive(:mhv_account_type).twice.and_return('Advanced')
              expect(subject.account_state).to eq('registered')
              expect(subject.changes).to be_empty
              expect(subject).not_to be_creatable
              expect(subject).to be_upgradable
              expect(subject).to be_terms_and_conditions_accepted
            end

            it 'has registered, upgradable with account level nil' do
              expect_any_instance_of(User).to receive(:mhv_account_type).twice.and_return(nil)
              expect(subject.account_state).to eq('registered')
              expect(subject.changes).to be_empty
              expect(subject).not_to be_creatable
              expect(subject).to be_upgradable
              expect(subject).to be_terms_and_conditions_accepted
            end

            it 'has registered, NOT upgradable with account level Error' do
              expect_any_instance_of(User).to receive(:mhv_account_type).twice.and_return('Error')
              expect(subject.account_state).to eq('registered')
              expect(subject.changes).to be_empty
              expect(subject).not_to be_creatable
              expect(subject).not_to be_upgradable
              expect(subject).to be_terms_and_conditions_accepted
            end
          end
        end
      end
    end
  end
end
