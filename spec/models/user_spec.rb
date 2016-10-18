# frozen_string_literal: true
require 'rails_helper'

RSpec.describe User, type: :model do
  let(:loa_one) { { current: LOA::ONE } }
  let(:loa_three) { { current: LOA::THREE } }

  describe '.create()' do
    context 'with LOA 1' do
      subject(:loa1_user) { described_class.new(FactoryGirl.build(:user, loa: loa_one)) }
      it 'should allow a blank ssn' do
        expect(FactoryGirl.build(:user, loa: loa_one, ssn: '')).to be_valid
      end
      it 'should allow a blank gender' do
        expect(FactoryGirl.build(:user, loa: loa_one, gender: '')).to be_valid
      end
      it 'should allow a blank middle_name' do
        expect(FactoryGirl.build(:user, loa: loa_one, middle_name: '')).to be_valid
      end
      it 'should allow a blank birth_date' do
        expect(FactoryGirl.build(:user, loa: loa_one, birth_date: '')).to be_valid
      end
      it 'should allow a blank zip' do
        expect(FactoryGirl.build(:user, loa: loa_one, zip: '')).to be_valid
      end
      it 'should allow a blank loa.highest' do
        expect(FactoryGirl.build(:user, loa: { current: LOA::ONE, highest: '' })).to be_valid
      end
      it 'should not allow a blank uuid' do
        loa1_user.uuid = ''
        expect(loa1_user.valid?).to be_falsey
        expect(loa1_user.errors[:uuid].size).to be_positive
      end
      it 'should not allow a blank email' do
        loa1_user.email = ''
        expect(loa1_user.valid?).to be_falsey
        expect(loa1_user.errors[:email].size).to be_positive
      end
    end
    context 'with LOA 3' do
      subject(:loa3_user) { described_class.new(FactoryGirl.build(:user, loa: loa_three)) }
      it 'should not allow a blank ssn' do
        loa3_user.ssn = ''
        expect(loa3_user.valid?).to be_falsey
        expect(loa3_user.errors[:ssn].size).to be_positive
      end
      it 'should not allow a blank first_name' do
        loa3_user.first_name = ''
        expect(loa3_user.valid?).to be_falsey
        expect(loa3_user.errors[:first_name].size).to be_positive
      end
      it 'should not allow a blank last_name' do
        loa3_user.last_name = ''
        expect(loa3_user.valid?).to be_falsey
        expect(loa3_user.errors[:last_name].size).to be_positive
      end
      it 'should not allow a blank birth_date' do
        loa3_user.birth_date = ''
        expect(loa3_user.valid?).to be_falsey
        expect(loa3_user.errors[:birth_date].size).to be_positive
      end
      it 'should not allow a blank gender' do
        loa3_user.gender = ''
        expect(loa3_user.valid?).to be_falsey
        expect(loa3_user.errors[:gender].size).to be_positive
      end
      it 'should not allow a gender other than M or F' do
        loa3_user.gender = 'male'
        expect(loa3_user.valid?).to be_falsey
        expect(loa3_user.errors[:gender].size).to be_positive
        loa3_user.gender = 'female'
        expect(loa3_user.valid?).to be_falsey
        expect(loa3_user.errors[:gender].size).to be_positive
        loa3_user.gender = 'Z'
        expect(loa3_user.valid?).to be_falsey
        expect(loa3_user.errors[:gender].size).to be_positive
      end
      it 'should allow a gender of M' do
        loa3_user.gender = 'M'
        expect(loa3_user.valid?).to be_truthy
      end
      it 'should allow a gender of F' do
        loa3_user.gender = 'F'
        expect(loa3_user.valid?).to be_truthy
      end
    end
  end

  subject { described_class.new(FactoryGirl.build(:user)) }
  context 'with an invalid ssn' do
    it 'should have an error on ssn' do
      subject.ssn = '111-22-3333'
      expect(subject.valid?).to be_falsey
      expect(subject.errors[:ssn].size).to eq(1)
    end
  end

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

    describe '#update' do
      context 'with a partial update' do
        it 'updates only user the user attributes passed in as arguments' do
          expect(subject).to receive(:save).once
          subject.update(
            mvi: {
              edipi: '1234^NI^200DOD^USDOD^A',
              icn: '1000123456V123456^NI^200M^USVHA^P',
              mhv_id: '123456^PI^200MHV^USVHA^A'
            }
          )
          expect(subject.attributes).to eq(
            FactoryGirl.build(
              :user,
              mvi: {
                edipi: '1234^NI^200DOD^USDOD^A',
                icn: '1000123456V123456^NI^200M^USVHA^P',
                mhv_id: '123456^PI^200MHV^USVHA^A'
              }
            ).attributes
          )
        end
      end
    end

    describe '#destroy' do
      it 'can destroy a user in redis' do
        expect(subject.destroy).to eq(1)
        expect(described_class.find(subject.uuid)).to be_nil
      end
    end
  end
end
