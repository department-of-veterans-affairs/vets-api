# frozen_string_literal: true

require 'rails_helper'
require 'inherited_proofing/user_attributes_fetcher'

RSpec.describe InheritedProofing::UserAttributesFetcher do
  describe '#perform' do
    subject do
      InheritedProofing::UserAttributesFetcher.new(auth_code:).perform
    end

    let(:auth_code) { 'some-auth-code' }
    let(:user) { create(:user, :mhv) }
    let(:user_uuid) { user.uuid }

    context 'when MHVIdentityData for auth_code does not exist' do
      let(:expected_error) { InheritedProofing::Errors::MHVIdentityDataNotFoundError }

      it 'returns MHV Identity data not found error' do
        expect { subject }.to raise_error(expected_error)
      end
    end

    context 'and MHVIdentityData for auth_code does exist' do
      let!(:mhv_identity_data) { create(:mhv_identity_data, code: auth_code, user_uuid:) }

      context 'and User does not exist for matching user_uuid' do
        let(:user_uuid) { 'some-non-existing-user-uuid' }
        let(:expected_error) { InheritedProofing::Errors::UserNotFoundError }

        it 'returns user not found error' do
          expect { subject }.to raise_error(expected_error)
        end
      end

      context 'and User does exist for matching user_uuid' do
        let(:user) do
          create(:user, :loa3,
                 first_name:, last_name:, address:,
                 home_phone:, birth_date:, ssn:)
        end
        let(:first_name) { 'some-first-name' }
        let(:last_name) { 'some-last-name' }
        let(:address) do
          { street: 'some-street', street2: 'some-street-2', city: 'some-city',
            state: 'some-state', country: 'some-country', postal_code: 'some-postal-code' }
        end
        let(:expected_mhv_data) { mhv_identity_data.data }
        let(:home_phone) { 'some-phone' }
        let(:birth_date) { '2021-01-01' }
        let(:ssn) { '123456789' }
        let(:expected_error) { InheritedProofing::Errors::UserMissingAttributesError }

        context 'and first name on user does not exist' do
          let(:first_name) { nil }

          it 'returns user missing attributes error' do
            expect { subject }.to raise_error(expected_error)
          end
        end

        context 'and last name on user does not exist' do
          let(:last_name) { nil }

          it 'returns user missing attributes error' do
            expect { subject }.to raise_error(expected_error)
          end
        end

        context 'and birth date on user does not exist' do
          let(:birth_date) { nil }

          it 'returns user missing attributes error' do
            expect { subject }.to raise_error(expected_error)
          end
        end

        context 'and ssn on user does not exist' do
          let(:ssn) { nil }

          it 'returns user missing attributes error' do
            expect { subject }.to raise_error(expected_error)
          end
        end

        context 'and address on user does not exist' do
          let(:address) { {} }

          it 'returns user missing attributes error' do
            expect { subject }.to raise_error(expected_error)
          end
        end

        context 'and required attributes on the user are present' do
          it 'returns expected hash of user attributes' do
            user_attribute_hash = subject

            expect(user_attribute_hash[:first_name]).to eq(first_name)
            expect(user_attribute_hash[:last_name]).to eq(last_name)
            expect(user_attribute_hash[:address]).to eq(address)
            expect(user_attribute_hash[:mhv_data]).to eq(expected_mhv_data)
            expect(user_attribute_hash[:phone]).to eq(home_phone)
            expect(user_attribute_hash[:birth_date]).to eq(birth_date)
            expect(user_attribute_hash[:ssn]).to eq(ssn)
          end
        end
      end

      it 'destroys the existing MHVIdentityData' do
        expect(InheritedProofing::MHVIdentityData.find(auth_code).attributes).to eq(mhv_identity_data.attributes)
        expect { subject }.to change {
          InheritedProofing::MHVIdentityData.find(auth_code)&.attributes
        }.from(mhv_identity_data.attributes).to(nil)
      end
    end
  end
end
