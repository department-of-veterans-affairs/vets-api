# frozen_string_literal: true

require 'rails_helper'
require 'meb_api/errors'

RSpec.describe MebApi::Errors::ClaimantNotFoundError do
  it 'has the default message' do
    expect(described_class.new.message).to eq('Claimant not found')
  end

  it 'accepts a custom message' do
    expect(described_class.new('Custom').message).to eq('Custom')
  end
end
