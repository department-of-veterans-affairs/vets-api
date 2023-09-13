# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TermsOfUseAgreement, type: :model do
  let(:terms_of_use_agreement) do
    build(:terms_of_use_agreement, user_account:, response:, agreement_version:)
  end
  let(:user_account) { create(:user_account) }
  let(:response) { 'accepted' }
  let(:agreement_version) { 'V1' }

  describe 'associations' do
    it 'belongs to a user_account' do
      expect(terms_of_use_agreement.user_account).to eq(user_account)
    end
  end

  describe 'validations' do
    context 'when all attributes are valid' do
      it 'is valid' do
        expect(terms_of_use_agreement).to be_valid
      end
    end

    context 'when response is missing' do
      let(:response) { nil }

      it 'is invalid' do
        expect(terms_of_use_agreement).not_to be_valid
        expect(terms_of_use_agreement.errors.attribute_names).to include(:response)
      end
    end

    context 'when agreement_version is missing' do
      let(:agreement_version) { nil }

      it 'is invalid' do
        expect(terms_of_use_agreement).not_to be_valid
        expect(terms_of_use_agreement.errors.attribute_names).to include(:agreement_version)
      end
    end

    describe 'response enum' do
      context 'when response is accepted' do
        let(:response) { 'accepted' }

        it 'is valid' do
          expect(terms_of_use_agreement).to be_valid
        end
      end

      context 'when response is declined' do
        let(:response) { 'declined' }

        it 'is valid' do
          expect(terms_of_use_agreement).to be_valid
        end
      end

      context 'when response is not accepted or declined' do
        it 'is invalid' do
          expect do
            terms_of_use_agreement.response = 'other_value'
          end.to raise_error(ArgumentError, "'other_value' is not a valid response")
        end
      end
    end
  end
end
