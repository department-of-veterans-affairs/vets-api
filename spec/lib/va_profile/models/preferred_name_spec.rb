# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/preferred_name'

describe VAProfile::Models::PreferredName,  feature: :personal_info,
                                            team_owner: :vfs_authenticated_experience_backend,
                                            type: :model do
  let(:model) { VAProfile::Models::PreferredName.new }

  # must only contain alpha, -, acute, grave, diaresis, cirumflex, tilde (case insensitive)
  context 'is valid' do
    it 'when contains alpha characters' do
      model.text = 'Pat'
      model.valid?
      expect(model).to be_valid
    end

    it 'when contains a dash' do
      model.text = 'mr-robot'
      model.valid?
      expect(model).to be_valid
    end

    it 'when contains an acute' do
      model.text = 'mistér'
      model.valid?
      expect(model).to be_valid
    end

    it 'when contains an grave' do
      model.text = 'mistàr'
      model.valid?
      expect(model).to be_valid
    end

    it 'when contains an diaeresis' do
      model.text = 'mistër'
      model.valid?
      expect(model).to be_valid
    end

    it 'when contains an circumflex' do
      model.text = 'mistâ'
      model.valid?
      expect(model).to be_valid
    end

    it 'when contains an tilde' do
      model.text = 'mistã'
      model.valid?
      expect(model).to be_valid
    end

    it 'when text contains a space' do
      model.text = 'mr robot'
      model.valid?
      expect(model).to be_valid
    end
  end

  context 'is invalid' do
    it 'when blank' do
      ['', ' ', nil].each do |entry|
        model.text = entry
        expect(model.valid?).to be(false)
        expect(model.errors[:text]).to include("can't be blank")
      end
    end

    it 'when text length is over 25' do
      model.text = 'a' * 26
      expect(model.valid?).to be(false)
      expect(model.errors[:text]).to include('is too long (maximum is 25 characters)')
    end

    it 'when text contains a digit' do
      model.text = 'mrrobot1'
      expect(model.valid?).to be(false)
      expect(model.errors[:text]).to include(
        'must only contain alpha, -, space, acute, grave, diaeresis, circumflex, tilde'
      )
    end

    it 'when text contains a special character' do
      special_chars = ['&', '$', '@', '%', '*']
      special_chars.each do |special_char|
        model.text = special_char
        expect(model.valid?).to be(false)
        expect(model.errors[:text]).to include(
          'must only contain alpha, -, space, acute, grave, diaeresis, circumflex, tilde'
        )
      end
    end
  end

  context 'removes spaces' do
    it 'when leading' do
      model.text = ' mr robot'
      model.valid?

      expect(model.text).to eq('mr robot')
      expect(model).to be_valid
    end

    it 'when trailing' do
      model.text = 'mr robot '
      model.valid?

      expect(model.text).to eq('mr robot')
      expect(model).to be_valid
    end
  end
end
