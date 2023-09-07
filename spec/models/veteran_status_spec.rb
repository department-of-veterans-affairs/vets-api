# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/veteran_status'

describe VAProfile::Models::VeteranStatus do
  let(:model) { VAProfile::Models::VeteranStatus.new }

  it 'is valid' do
    model.title_38_status_code = 'V1'
    model.valid?
    expect(model).to be_valid
  end

  it 'is invalid without text' do
    model.title_38_status_code = nil
    model.valid?
    expect(model.errors[:title_38_status_code]).to include("can't be blank")
  end

  it 'is invalid when text length is over 25' do
    model.title_38_status_code = 'a' * 26
    model.valid?
    expect(model.errors[:title_38_status_code]).to include('is too long (maximum is 25 characters)')
  end
end
