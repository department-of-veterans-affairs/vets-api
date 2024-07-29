# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::User, type: :model do
  let!(:user) { create(:representation_management_user, postal_code: '11201') }

  describe 'blind indexing' do
    it 'encrypts the postal_code attribute' do
      expect(user.postal_code_ciphertext).not_to be_nil
      expect(user.postal_code_ciphertext).not_to eq '11201'
    end

    it 'creates a blind index for postal_code' do
      expect(user.postal_code_bidx).not_to be_nil
    end

    it 'can find a user by their postal code using the blind index' do
      found_user = RepresentationManagement::User.find_by(postal_code: '11201')
      expect(found_user).to eq(user)
    end

    it 'cannot find a user with an incorrect postal code' do
      found_user = RepresentationManagement::User.find_by(postal_code: '11202')
      expect(found_user).to be_nil
    end
  end
end
