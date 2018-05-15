# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MhvAccount, type: :model do
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

  before(:each) do
    stub_mvi(mvi_profile)
  end

  around(:each) do |example|
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
          expect(subject.creatable?).to be_falsey
        end
      end

      context 'user ssn mismatch' do
        let(:user_ssn) { '123456789' }

        it 'needs_ssn_resolution' do
          expect(subject.account_state).to eq('needs_ssn_resolution')
          expect(subject.creatable?).to be_falsey
        end
      end

      context 'user not a va patient' do
        let(:vha_facility_ids) { ['999'] }

        it 'needs_va_patient' do
          expect(subject.account_state).to eq('needs_va_patient')
          expect(subject.creatable?).to be_falsey
        end
      end

      context 'user has previously deactivated mhv ids' do
        let(:mhv_ids) { %w[14221465 14221466] }
        let(:active_mhv_ids) { %w[14221466] }

        it 'has_deactivated_mhv_ids' do
          expect(subject.account_state).to eq('has_deactivated_mhv_ids')
          expect(subject.creatable?).to be_falsey
        end
      end

      context 'user has multiple active mhv ids' do
        let(:mhv_ids) { %w[14221465 14221466] }
        let(:active_mhv_ids) { mhv_ids }

        it 'has_multiple_active_mhv_ids' do
          expect(subject.account_state).to eq('has_multiple_active_mhv_ids')
          expect(subject.creatable?).to be_falsey
        end
      end

      context 'user has not accepted terms and conditions' do
        let(:mhv_ids) { %w[14221465] }

        it 'needs_terms_acceptance' do
          expect(subject.account_state).to eq('needs_terms_acceptance')
          expect(subject.creatable?).to be_falsey
        end
      end
    end

    context 'check_account_state' do
      context 'with terms accepted' do
        let(:terms) { create(:terms_and_conditions, latest: true, name: described_class::TERMS_AND_CONDITIONS_NAME) }
        before(:each) { create(:terms_and_conditions_acceptance, terms_and_conditions: terms, user_uuid: user.uuid) }

        context 'without an existing account' do
          context 'nothing has been persisted and no mhv_id' do
            it 'has no_account' do
              expect(subject.account_state).to eq('no_account')
              expect(subject.creatable?).to be_truthy
              expect(subject.terms_and_conditions_accepted?).to be_truthy
            end
          end
        end

        context 'with existing account' do
          let(:mhv_ids) { %w[14221465] }

          context 'nothing has been persisted with current mhv id' do
            before(:each) do
              allow_any_instance_of(MhvAccountTypeService)
                .to receive(:mhv_account_type).and_return(account_type)
            end

            context 'account level basic' do
              let(:account_type) { 'Basic' }

              it 'has existing' do
                expect(subject.account_state).to eq('existing')
                expect(subject.creatable?).to be_falsey
                expect(subject.upgradable?).to be_truthy
                expect(subject.terms_and_conditions_accepted?).to be_truthy
              end
            end

            context 'account level advanced' do
              let(:account_type) { 'Advanced' }

              it 'has existing' do
                expect(subject.account_state).to eq('existing')
                expect(subject.creatable?).to be_falsey
                expect(subject.upgradable?).to be_truthy
                expect(subject.terms_and_conditions_accepted?).to be_truthy
              end
            end

            context 'account level premium' do
              let(:account_type) { 'Premium' }

              it 'has existing' do
                expect(subject.account_state).to eq('existing')
                expect(subject.creatable?).to be_falsey
                expect(subject.upgradable?).to be_falsey
                expect(subject.terms_and_conditions_accepted?).to be_truthy
              end
            end

            context 'account level unknown' do
              let(:account_type) { 'Unknown' }

              it 'has existing' do
                expect(subject.account_state).to eq('existing')
                expect(subject.creatable?).to be_falsey
                expect(subject.upgradable?).to be_falsey
                expect(subject.terms_and_conditions_accepted?).to be_truthy
              end
            end

            context 'account level unknown' do
              let(:account_type) { 'Error' }

              it 'has existing' do
                expect(subject.account_state).to eq('existing')
                expect(subject.creatable?).to be_falsey
                expect(subject.upgradable?).to be_falsey
                expect(subject.terms_and_conditions_accepted?).to be_truthy
              end
            end
          end

          context 'previously upgraded' do
            before(:each) do
              MhvAccount.skip_callback(:initialize, :after, :setup)
              create(:mhv_account, :upgraded, user_uuid: user.uuid, mhv_correlation_id: user.mhv_correlation_id)
              MhvAccount.set_callback(:initialize, :after, :setup)
            end

            it 'has upgraded' do
              expect(subject.account_state).to eq('upgraded')
              expect(subject.creatable?).to be_falsey
              expect(subject.upgradable?).to be_falsey
              expect(subject.terms_and_conditions_accepted?).to be_truthy
            end
          end

          context 'previously registered' do
            before(:each) do
              MhvAccount.skip_callback(:initialize, :after, :setup)
              create(:mhv_account, :registered, user_uuid: user.uuid, mhv_correlation_id: user.mhv_correlation_id)
              MhvAccount.set_callback(:initialize, :after, :setup)
            end

            it 'has registered' do
              expect(subject.account_state).to eq('registered')
              expect(subject.creatable?).to be_falsey
              expect(subject.upgradable?).to be_falsey
              expect(subject.terms_and_conditions_accepted?).to be_truthy
            end
          end
        end
      end
    end
  end
end
