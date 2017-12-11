# frozen_string_literal: true
require 'rails_helper'

RSpec.describe User, type: :model do
  let(:loa_one) { { current: LOA::ONE } }
  let(:loa_three) { { current: LOA::THREE } }

  describe '#can_prefill_emis?' do
    let(:user) { build(:user, :loa3) }

    before do
      expect(user).to receive('beta_enabled?').with(user.uuid, 'emis_prefill').and_return(true)
    end

    it 'should return true if the user has the right epipi' do
      expect(user.can_prefill_emis?).to eq(true)
    end
  end

  describe '.create()' do
    context 'with LOA 1' do
      subject(:loa1_user) { described_class.new(FactoryBot.build(:user, loa: loa_one)) }

      it 'should not allow a blank uuid' do
        loa1_user.uuid = ''
        expect(loa1_user.valid?).to be_falsey
        expect(loa1_user.errors[:uuid].size).to be_positive
      end
    end
  end

  subject { described_class.new(FactoryBot.build(:user)) }

  context 'user without attributes' do
    let(:test_user) { FactoryBot.build(:user) }

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

    describe 'getter methods' do
      context 'when icn is available from saml data and user LOA3' do
        let(:mvi_profile) { FactoryBot.build(:mvi_profile) }
        let(:user) { FactoryBot.build(:user, :loa3, mhv_icn: mvi_profile.icn) }
        before(:each) { stub_mvi(mvi_profile) }

        it 'fetches first_name from mvi' do
          expect(user.first_name).not_to eq(user.identity.first_name)
          expect(user.first_name).to eq(mvi_profile.given_names.first)
        end

        it 'fetches middle_name from mvi' do
          expect(user.middle_name).not_to eq(user.identity.middle_name)
          expect(user.middle_name).to eq(mvi_profile.given_names.last)
        end

        it 'fetches last_name from mvi' do
          expect(user.last_name).not_to eq(user.identity.last_name)
          expect(user.last_name).to eq(mvi_profile.family_name)
        end

        it 'fetches gender from mvi' do
          expect(user.gender).not_to eq(user.identity.gender)
          expect(user.gender).to eq(mvi_profile.gender)
        end

        it 'fetches birth_date from mvi' do
          expect(user.birth_date).not_to eq(user.identity.birth_date)
          expect(user.birth_date).to eq(mvi_profile.birth_date)
        end

        it 'fetches zip from mvi' do
          expect(user.zip).not_to eq(user.identity.zip)
          expect(user.zip).to eq(mvi_profile.address.postal_code)
        end

        it 'fetches ssn from mvi' do
          expect(user.ssn).not_to eq(user.identity.ssn)
          expect(user.ssn).to eq(mvi_profile.ssn)
        end
      end

      context 'when icn is available from saml data and user NOT LOA3' do
        let(:mvi_profile) { FactoryBot.build(:mvi_profile) }
        let(:user) { FactoryBot.build(:user, :loa1, mhv_icn: mvi_profile.icn) }
        before(:each) { stub_mvi(mvi_profile) }

        it 'fetches first_name from mvi' do
          expect(user.first_name).to be_nil
        end

        it 'fetches middle_name from mvi' do
          expect(user.middle_name).to be_nil
        end

        it 'fetches last_name from mvi' do
          expect(user.last_name).to be_nil
        end

        it 'fetches gender from mvi' do
          expect(user.gender).to be_nil
        end

        it 'fetches birth_date from mvi' do
          expect(user.birth_date).to be_nil
        end

        it 'fetches zip from mvi' do
          expect(user.zip).to be_nil
        end

        it 'fetches ssn from mvi' do
          expect(user.ssn).to be_nil
        end
      end

      context 'when icn is not available from saml data' do
        let(:mvi_profile) { FactoryBot.build(:mvi_profile) }
        let(:user) { FactoryBot.build(:user, :loa3) }
        before(:each) { stub_mvi(mvi_profile) }

        it 'fetches first_name from UserIdentity' do
          expect(user.first_name).to eq(user.identity.first_name)
          expect(user.first_name).not_to eq(mvi_profile.given_names.first)
        end

        it 'fetches middle_name from UserIdentity' do
          expect(user.middle_name).to eq(user.identity.middle_name)
          expect(user.middle_name).not_to eq(mvi_profile.given_names.last)
        end

        it 'fetches last_name from UserIdentity' do
          expect(user.last_name).to eq(user.identity.last_name)
          expect(user.last_name).not_to eq(mvi_profile.family_name)
        end

        it 'fetches gender from UserIdentity' do
          expect(user.gender).to eq(user.identity.gender)
        end

        it 'fetches birth_date from UserIdentity' do
          expect(user.birth_date).to eq(user.identity.birth_date)
          expect(user.birth_date).not_to eq(mvi_profile.birth_date)
        end

        it 'fetches zip from UserIdentity' do
          expect(user.zip).to eq(user.identity.zip)
          expect(user.zip).not_to eq(mvi_profile.address.postal_code)
        end

        it 'fetches ssn from UserIdentity' do
          expect(user.ssn).to eq(user.identity.ssn)
          expect(user.ssn).not_to eq(mvi_profile.ssn)
        end
      end

      describe '#mhv_correlation_id' do
        context 'when mhv ids are nil' do
          let(:user) { FactoryBot.build(:user) }
          it 'has a mhv correlation id of nil' do
            expect(user.mhv_correlation_id).to be_nil
          end
        end
        context 'when there are mhv ids' do
          let(:loa3_user) { FactoryBot.build(:user, :loa3) }
          let(:mvi_profile) { FactoryBot.build(:mvi_profile) }
          it 'has a mhv correlation id' do
            stub_mvi(mvi_profile)
            expect(loa3_user.mhv_correlation_id).to eq(mvi_profile.mhv_ids.first)
          end
        end
      end
    end
  end
end
