# frozen_string_literal: true
require 'rails_helper'

RSpec.describe SingleLogoutRequest, type: :model do
  it 'requires the precense of token' do
    slr = SingleLogoutRequest.new(uuid: '1234')
    expect(slr).to be_invalid
  end
  it 'requires the precense of uuid' do
    slr = SingleLogoutRequest.new(token: '1234')
    expect(slr).to be_invalid
  end
end
