# frozen_string_literal: true
require 'rails_helper'
require 'support/attr_encrypted_matcher'

RSpec.describe FormProfile, type: :model do
  let(:user) { build(:loa3_user) }

  describe 'form encryption' do
    it 'encrypts form applicant_information' do
      expect(subject).to encrypt_attr(:form_profile)
    end
  end

  describe '#query' do
    context 'when there is no form profile record' do
      it 'should return the va profile' do
        expect(Mvi).to receive(:find).once
        expect(subject.query(user, 'edu_benefits')).to eq({
          veteranInformation: {
            fullName: {
              first: 'Abraham',
              middle: nil,
              last: 'Lincoln',
              suffix: nil
            }
          },
          contactInformation: {
            address: {
              street: '140 Rock Creek Church Road NW',
              street2: nil,
              city: 'Washington',
              state: 'DC',
              postalCode: '20011',
              country: 'USA'
            },
            homePhone: '2028290436',
            mobilePhone: nil
          }
        })
      end
    end
    context 'when there is a form profile record with missing properties' do
      let!(:in_progress_form) { FactoryGirl.create(:form_profile) }

      it 'should return the stored profile rather than the va profile' do
        expect(Mvi).to_not receive(:find).once
        expect(subject.query(user, 'edu_benefits')).to eq({
          veteranInformation: {
            fullName: {
              first: 'Abraham',
              middle: 'Vampire Hunter',
              last: 'Lincoln',
              suffix: nil
            }
          },
          contactInformation: {
            address: {
              street: '140 Rock Creek Church Road NW',
              street2: nil,
              city: 'Washington',
              state: 'DC',
              postalCode: '20011',
              country: 'USA'
            },
            homePhone: '2028290436',
            mobilePhone: nil
          }
        })
      end
    end
  end
end
