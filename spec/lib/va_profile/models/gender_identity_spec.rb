# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/gender_identity'

describe VAProfile::Models::GenderIdentity, feature: :personal_info,
                                            team_owner: :vfs_authenticated_experience_backend,
                                            type: :model do
  let(:model) { VAProfile::Models::GenderIdentity.new(code: 'F', name: 'Woman') }

  context 'is valid' do
    it 'when code is valid' do
      model.valid?
      expect(model).to be_valid
    end

    it 'name is set from code' do
      model.code = 'M'
      model.valid?
      expect(model.name).to eq('Man')
    end
  end

  context 'is invalid' do
    it 'when code is missing' do
      model.code = nil
      model.valid?
      expect(model.errors.count).to eq(1)
      expect(model.errors[:code]).to include("can't be blank")
      expect(model.name).to be_nil
    end

    it 'when code is an invalid option' do
      model.code = 'X'
      model.valid?
      expect(model.errors.count).to eq(1)
      expect(model.errors[:code]).to include('invalid code')
      expect(model.name).to be_nil
    end
  end
end
