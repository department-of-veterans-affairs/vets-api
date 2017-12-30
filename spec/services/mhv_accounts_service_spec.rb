# frozen_string_literal: true
require 'rails_helper'

RSpec.describe MhvAccountsService do
  let(:mvi_profile) do
    build(:mvi_profile,
          icn: '1012667122V019349',
          given_names: %w(Hector),
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

  let(:terms) { create(:terms_and_conditions, latest: true, name: MhvAccount::TERMS_AND_CONDITIONS_NAME) }
  let(:tc_accepted) { double('terms_and_conditions_accepted', terms_and_conditions: terms, created_at: Time.current) }
  let(:mhv_account) do
    double(
      'mhv_account',
      may_register?: true,
      may_upgrade?: true,
      terms_and_conditions_accepted: tc_accepted
    )
  end

  subject { described_class.new(user) }
  before(:each) do
    stub_mvi(mvi_profile)
    allow(MhvAccount).to receive(:find_or_initialize_by).and_return(mhv_account)
  end

  describe 'account creation and upgrade' do
    context 'account creation' do
      before(:each) do
        allow(mhv_account).to receive(:registered_at=)
        allow(mhv_account).to receive(:register!)
      end

      it 'handles failure to create' do
        allow_any_instance_of(MHVAC::Client).to receive(:post_register).and_raise(StandardError, 'random')
        expect(mhv_account).to receive(:fail_register!)
        expect { subject.create }.to raise_error(StandardError, 'random')
          .and not_trigger_statsd_increment('mhv.account.creation.success')
          .and trigger_statsd_increment('mhv.account.creation.failure')
      end

      it 'successfully creates' do
        VCR.use_cassette('mhv_account_creation/creates_an_account') do
          expect(mhv_account).to receive(:registered_at=).with(kind_of(Time))
          expect(mhv_account).to receive(:register!)
          expect { subject.create }.to trigger_statsd_increment('mhv.account.creation.success')
            .and not_trigger_statsd_increment('mhv.account.creation.failure')
          expect(User.find(user.uuid).mhv_correlation_id).to eq('14221465')
        end
      end
    end

    context 'account upgrade' do
      let(:mhv_ids) { ['14221465'] }

      before(:each) do
        allow(mhv_account).to receive(:upgraded_at=)
        allow(mhv_account).to receive(:upgrade!)
      end

      it 'handles unknown failure to upgrade' do
        VCR.use_cassette('mhv_account_creation/account_upgrade_unknown_error', record: :none) do
          expect(mhv_account).to receive(:fail_upgrade!)
          expect { subject.upgrade }.to raise_error(Common::Exceptions::BackendServiceException)
            .and not_trigger_statsd_increment('mhv.account.existed')
            .and not_trigger_statsd_increment('mhv.account.upgrade.success')
            .and trigger_statsd_increment('mhv.account.upgrade.failure')
        end
      end

      it 'handles an already upgraded account' do
        VCR.use_cassette('mhv_account_creation/should_not_upgrade_an_account_if_one_already_exists') do
          expect(mhv_account).to receive(:upgrade!)
          expect { subject.upgrade }.to trigger_statsd_increment('mhv.account.existed')
            .and not_trigger_statsd_increment('mhv.account.upgrade.success')
            .and not_trigger_statsd_increment('mhv.account.upgrade.failure')
        end
      end

      it 'successfully upgrades' do
        VCR.use_cassette('mhv_account_creation/upgrades_an_account') do
          expect(mhv_account).to receive(:upgraded_at=).with(kind_of(Time))
          expect(mhv_account).to receive(:upgrade!)
          expect { subject.upgrade }.to trigger_statsd_increment('mhv.account.upgrade.success')
            .and not_trigger_statsd_increment('mhv.account.creation.failure')
        end
      end
    end
  end

  describe 'address population' do
    let(:ac_client) { instance_double('MHVAC::Client') }

    before(:each) do
      allow(SM::Client).to receive(:new).and_return(ac_client)
      allow(subject).to receive(:mhv_ac_client) { ac_client }
      allow(mhv_account).to receive(:registered_at=)
      allow(mhv_account).to receive(:register!)
      allow(mhv_account).to receive(:upgraded_at=)
      allow(mhv_account).to receive(:upgrade!)
    end

    it 'uses MVI address if present' do
      expect(ac_client).to receive(:post_register).with(hash_including(
                                                          address1: '20140624',
                                                          city: 'Houston',
                                                          state: 'TX',
                                                          zip: '77040',
                                                          country: 'USA'
      )).and_return(api_completion_status: 'Successful', correlation_id: 123_456)
      expect(ac_client).to receive(:post_upgrade).and_return(status: 'success')
      subject.create
      subject.upgrade
    end

    context 'with nil MVI address' do
      let(:mvi_profile_address) { nil }
      it 'defaults address if MVI address nil' do
        expect(ac_client).to receive(:post_register).with(hash_including(
                                                            address1: 'Unknown Address',
                                                            city: 'Washington',
                                                            state: 'DC',
                                                            zip: '20571',
                                                            country: 'USA'
        )).and_return(api_completion_status: 'Successful', correlation_id: 123_456)
        expect(ac_client).to receive(:post_upgrade).and_return(status: 'success')
        subject.create
        subject.upgrade
      end
    end

    context 'with partially nil MVI address' do
      let(:mvi_profile_address) do
        build(:mvi_profile_address,
              street: '20140624',
              city: nil,
              state: 'TX',
              country: 'USA',
              postal_code: nil)
      end

      it 'defaults address if MVI address nil' do
        expect(ac_client).to receive(:post_register).with(hash_including(
                                                            address1: 'Unknown Address',
                                                            city: 'Washington',
                                                            state: 'DC',
                                                            zip: '20571',
                                                            country: 'USA'
        )).and_return(api_completion_status: 'Successful', correlation_id: 123_456)
        expect(ac_client).to receive(:post_upgrade).and_return(status: 'success')
        subject.create
        subject.upgrade
      end
    end
  end

  describe 'user veteran status' do
    let(:ac_client) { instance_double('MHVAC::Client') }

    before(:each) do
      allow(SM::Client).to receive(:new).and_return(ac_client)
      allow(subject).to receive(:mhv_ac_client) { ac_client }
      allow(mhv_account).to receive(:registered_at=)
      allow(mhv_account).to receive(:register!)
      allow(mhv_account).to receive(:upgraded_at=)
      allow(mhv_account).to receive(:upgrade!)
    end

    it 'sets is_veteran true if user is veteran' do
      allow(SM::Client).to receive(:new).and_return(ac_client)
      allow_any_instance_of(User).to receive(:veteran?).and_return(true)
      allow(subject).to receive(:mhv_ac_client) { ac_client }
      expect(ac_client).to receive(:post_register).with(hash_including(
                                                          is_veteran: true
      )).and_return(api_completion_status: 'Successful', correlation_id: 123_456)
      expect(ac_client).to receive(:post_upgrade).and_return(status: 'success')
      subject.create
      subject.upgrade
    end

    it 'sets is_veteran false if user is not veteran' do
      allow(SM::Client).to receive(:new).and_return(ac_client)
      allow_any_instance_of(User).to receive(:veteran?).and_return(false)
      allow(subject).to receive(:mhv_ac_client) { ac_client }
      expect(ac_client).to receive(:post_register).with(hash_including(
                                                          is_veteran: false
      )).and_return(api_completion_status: 'Successful', correlation_id: 123_456)
      expect(ac_client).to receive(:post_upgrade).and_return(status: 'success')
      subject.create
      subject.upgrade
    end

    it 'sets is_veteran false if veteran status is unknown' do
      allow(SM::Client).to receive(:new).and_return(ac_client)
      allow_any_instance_of(User).to receive(:veteran?).and_raise(StandardError)
      allow(subject).to receive(:mhv_ac_client) { ac_client }
      expect(ac_client).to receive(:post_register).with(hash_including(
                                                          is_veteran: false
      )).and_return(api_completion_status: 'Successful', correlation_id: 123_456)
      expect(ac_client).to receive(:post_upgrade).and_return(status: 'success')
      subject.create
      subject.upgrade
    end
  end
end
