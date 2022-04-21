# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/preferred_name'

describe VAProfile::Models::PreferredName do
  let(:model) { VAProfile::Models::PreferredName.new }

  it 'is valid' do
    model.text = 'Pat'
    model.valid?
    expect(model).to be_valid
  end

  it 'is invalid without text' do
    model.text = nil
    model.valid?
    expect(model.errors[:text]).to include("can't be blank")
  end

  it 'is invalid when text length is over 25' do
    model.text = 'a' * 26
    model.valid?
    expect(model.errors[:text]).to include('is too long (maximum is 25 characters)')
  end
end
