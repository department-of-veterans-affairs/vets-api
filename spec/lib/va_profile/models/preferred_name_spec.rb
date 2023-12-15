# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/preferred_name'

describe VAProfile::Models::PreferredName do
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
  end

  context 'is invalid' do
    it 'when blank' do
      model.text = nil
      model.valid?
      expect(model.errors[:text]).to include("can't be blank")
    end

    it 'when text length is over 25' do
      model.text = 'a' * 26
      model.valid?
      expect(model.errors[:text]).to include('is too long (maximum is 25 characters)')
    end

    it 'when text contains a space' do
      model.text = 'mr robot'
      model.valid?
      expect(model.errors[:text]).to include('must not contain spaces')
    end

    it 'when text contains a digit' do
      model.text = 'mrrobot1'
      model.valid?
      expect(model.errors[:text]).to include('must only contain alpha, -, acute, grave, diaresis, circumflex, tilde')
    end

    it 'when text contains a special character' do
      special_chars = ['&', '$', '@', '%', '*', ' ']
      special_chars.each do |special_char|
        model.text = special_char
        model.valid?
        expect(model.errors[:text]).to include('must only contain alpha, -, acute, grave, diaresis, circumflex, tilde')
      end
    end
  end
end
