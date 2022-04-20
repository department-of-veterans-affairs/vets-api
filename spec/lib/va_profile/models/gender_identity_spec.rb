# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/gender_identity'

describe VAProfile::Models::GenderIdentity do
  let(:model) { VAProfile::Models::GenderIdentity.new(code: 'F', name: 'Female') }

  context 'is valid' do
    it 'when code and name are valid' do
      model.valid?
      expect(model).to be_valid
    end
  end

  context 'is invalid' do
    it 'when code is missing' do
      model.code = nil
      model.valid?
      expect(model.errors.count).to eq(1)
      expect(model.errors[:code]).to include("can't be blank")
    end

    it 'when code is an invalid option' do
      model.code = 'X'
      model.valid?
      expect(model.errors.count).to eq(1)
      expect(model.errors[:code]).to include('invalid code')
    end

    it 'when name is missing' do
      model.name = nil
      model.valid?
      expect(model.errors.count).to eq(1)
      expect(model.errors[:name]).to include("can't be blank")
    end

    it 'when name is an invalid option' do
      model.name = 'X'
      model.valid?
      expect(model.errors.count).to eq(1)
      expect(model.errors[:name]).to include('invalid name')
    end

    it 'when code-name combination is invalid' do
      model.code = 'M'
      model.valid?
      expect(model.errors.count).to eq(1)
      expect(model.errors[:base]).to include('invalid code/name combination')
    end
  end
end
