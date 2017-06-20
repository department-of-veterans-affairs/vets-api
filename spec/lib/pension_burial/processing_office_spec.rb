# frozen_string_literal: true
require 'rails_helper'

RSpec.describe PensionBurial::ProcessingOffice do
  it 'should return an office name for a zip' do
    expect(described_class.from_zip(90_210)).to eq('St. Paul')
  end

  it 'should default to an office when no zip is mapped' do
    expect(described_class.from_zip(99_999)).to eq('Milwaukee')
  end
end
