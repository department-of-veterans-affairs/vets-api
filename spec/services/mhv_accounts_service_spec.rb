# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MhvAccountsService do
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
    create(:user, :loa3,
           ssn: mvi_profile.ssn,
           first_name: mvi_profile.given_names.first,
           last_name: mvi_profile.family_name,
           gender: mvi_profile.gender,
           birth_date: mvi_profile.birth_date,
           email: 'vets.gov.user+0@gmail.com')
  end

  let(:mhv_ids) { [] }
  let(:vha_facility_ids) { ['450'] }

  before(:each) do
    stub_mvi(mvi_profile)
    terms = create(:terms_and_conditions, latest: true, name: MhvAccount::TERMS_AND_CONDITIONS_NAME, version: 'v3.4')
    date_signed = Time.new(2017, 5, 9).utc
    create(:terms_and_conditions_acceptance, terms_and_conditions: terms, user_uuid: user.uuid, created_at: date_signed)
  end

  describe 'account creation and upgrade' do
    let(:mhv_account) { MhvAccount.new(user_uuid: user.uuid, mhv_correlation_id: user.mhv_correlation_id) }
    subject { described_class.new(mhv_account) }

    context 'account creation' do
      it 'handles failure to create' do
        allow_any_instance_of(MHVAC::Client).to receive(:post_register).and_raise(StandardError, 'random')
        expect(subject).to receive(:log_warning)

        expect { subject.create }.to raise_error(StandardError, 'random')
          .and not_trigger_statsd_increment('mhv.account.creation.success')
          .and trigger_statsd_increment('mhv.account.creation.failure')
        expect(mhv_account.account_state).to eq('register_failed')
        expect(mhv_account.persisted?).to be_falsey
      end

      it 'successfully creates', focus: true do
        VCR.use_cassette('mhv_account_creation/creates_an_account') do
          expect { subject.create }.to trigger_statsd_increment('mhv.account.creation.success')
            .and not_trigger_statsd_increment('mhv.account.creation.failure')
          expect(User.find(user.uuid).mhv_correlation_id).to eq('14221465')
          expect(mhv_account.account_state).to eq('registered')
          expect(mhv_account.registered_at).to be_a(Time)
          expect(mhv_account.persisted?).to be_truthy
        end
      end
    end

    context 'account upgrade' do
      let(:mhv_ids) { ['14221465'] }

      context 'with an existing basic account' do
        before(:each) { allow_any_instance_of(MhvAccountTypeService).to receive(:mhv_account_type).and_return('Basic') }

        it 'handles unknown failure to upgrade', focus: true do
          VCR.use_cassette('mhv_account_creation/account_upgrade_unknown_error') do
            expect { subject.upgrade }.to raise_error(Common::Exceptions::BackendServiceException)
              .and not_trigger_statsd_increment('mhv.account.existed')
              .and not_trigger_statsd_increment('mhv.account.upgrade.success')
              .and trigger_statsd_increment('mhv.account.upgrade.failure')
            expect(mhv_account.account_state).to eq('upgrade_failed')
            expect(mhv_account.persisted?).to be_falsey
          end
        end

        it 'successfully upgrades' do
          VCR.use_cassette('mhv_account_creation/upgrades_an_account') do
            expect { subject.upgrade }.to trigger_statsd_increment('mhv.account.upgrade.success')
              .and not_trigger_statsd_increment('mhv.account.creation.failure')
            expect(mhv_account.account_state).to eq('upgraded')
            expect(mhv_account.upgraded_at).to be_a(Time)
            expect(mhv_account.persisted?).to be_truthy
          end
        end
      end

      context 'an account that cannot be upgraded' do
        before(:each) { allow_any_instance_of(MhvAccountTypeService).to receive(:mhv_account_type).and_return('Premium') }

        it 'handles an already upgraded account' do
          expect { subject.upgrade }.to not_trigger_statsd_increment('mhv.account.upgrade.success')
            .and not_trigger_statsd_increment('mhv.account.upgrade.failure')
          expect(mhv_account.account_state).to eq('existing')
          expect(mhv_account.persisted?).to be_falsey
        end
      end
    end
  end
end
