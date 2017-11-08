# frozen_string_literal: true
require 'rails_helper'

RSpec.describe User, type: :model do
  let(:loa_one) { { current: LOA::ONE } }
  let(:loa_three) { { current: LOA::THREE } }

  describe '.from_merged_attrs()' do
    subject(:loa1_user) { build(:user, :loa1) }
    subject(:loa3_user) { build(:user, :loa3) }
    it 'should not down-level' do
      user = described_class.from_merged_attrs(loa3_user, loa1_user)
      expect(user.loa[:current]).to eq(loa3_user.loa[:current])
      expect(user.loa[:highest]).to eq(loa3_user.loa[:highest])
      expect(user).to be_valid
    end
    it 'should up-level' do
      user = described_class.from_merged_attrs(loa1_user, loa3_user)
      expect(user.loa[:current]).to eq(loa3_user.loa[:current])
      expect(user.loa[:highest]).to eq(loa3_user.loa[:highest])
      expect(user).to be_valid
    end
    it 'should use newer attrs unless they are empty or nil' do
      new_user = build(:user, :loa1, first_name: 'George', last_name: 'Washington', gender: '', birth_date: nil)
      user = described_class.from_merged_attrs(loa3_user, new_user)
      expect(user.first_name).to eq('George')
      expect(user.last_name).to eq('Washington')
      expect(user.gender).to eq(loa3_user.gender)
      expect(user.birth_date).to eq(loa3_user.birth_date)
      expect(user.zip).to eq(loa3_user.zip)
    end
  end

  describe '#can_prefill_emis?' do
    let(:user) { build(:user, :loa3) }

    before do
      expect(user).to receive('beta_enabled?').with(user.uuid, 'emis_prefill').and_return(true)
    end

    it 'should return true if the user has the right epipi' do
      expect(user.can_prefill_emis?).to eq(true)
    end
  end

  subject { described_class.new(FactoryGirl.build(:user)) }

  context 'user without attributes' do
    let(:test_user) { FactoryGirl.build(:user) }
    
    it 'expect ttl to an Integer' do
      expect(subject.ttl).to be_an(Integer)
      expect(subject.ttl).to be_between(-Float::INFINITY, 0)
    end

    it 'assigns an email' do
      expect(subject.email).to eq(test_user.email)
    end

    it 'assigns an uuid' do
      expect(subject.uuid).to eq(test_user.uuid)
    end

    it 'has a persisted attribute of false' do
      expect(subject.persisted?).to be_falsey
    end
  end

  it 'has a persisted attribute of false' do
    expect(subject.persisted?).to be_falsey
  end

  describe 'redis persistence' do
    before(:each) { subject.save }

    describe '#save' do
      it 'sets persisted flag to true' do
        expect(subject.persisted?).to be_truthy
      end

      it 'sets the ttl countdown' do
        expect(subject.ttl).to be_an(Integer)
        expect(subject.ttl).to be_between(0, 86_400)
      end
    end

    describe '.find' do
      let(:found_user) { described_class.find(subject.uuid) }

      it 'can find a saved user in redis' do
        expect(found_user).to be_a(described_class)
        expect(found_user.uuid).to eq(subject.uuid)
      end

      it 'expires and returns nil if user loaded from redis is invalid' do
        allow_any_instance_of(described_class).to receive(:valid?).and_return(false)
        expect(found_user).to be_nil
      end

      it 'returns nil if user was not found' do
        expect(described_class.find('non-existant-uuid')).to be_nil
      end
    end

    describe '#destroy' do
      it 'can destroy a user in redis' do
        expect(subject.destroy).to eq(1)
        expect(described_class.find(subject.uuid)).to be_nil
      end
    end

    describe '#mhv_correlation_id' do
      context 'when mhv ids are nil' do
        let(:user) { FactoryGirl.build(:user) }
        it 'has a mhv correlation id of nil' do
          expect(user.mhv_correlation_id).to be_nil
        end
      end
      context 'when there are mhv ids' do
        let(:loa3_user) { FactoryGirl.build(:user, :loa3) }
        let(:mvi_profile) { FactoryGirl.build(:mvi_profile) }
        it 'has a mhv correlation id' do
          stub_mvi(mvi_profile)
          expect(loa3_user.mhv_correlation_id).to eq(mvi_profile.mhv_ids.first)
        end
      end
    end
  end
end
