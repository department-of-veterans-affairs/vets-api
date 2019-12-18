# frozen_string_literal: true

require 'rails_helper'

describe Vet360::Models::Permission do
  describe 'validations' do
    it 'we have a valid factory in place' do
      expect(build(:permission)).to be_valid
    end

    context 'permission_type' do
      it 'is valid when populated' do
        permission = build(:permission, permission_type: 'TextPermission')
        expect(permission).to be_valid
      end

      it 'is not valid when nil' do
        permission = build(:permission, permission_type: nil)
        expect(permission).not_to be_valid
      end
    end

    context 'permission_value' do
      it 'is not valid when nil' do
        permission = build(:permission, permission_value: nil)
        expect(permission).not_to be_valid
      end
    end
  end
end
