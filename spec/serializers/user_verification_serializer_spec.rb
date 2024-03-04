# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserVerificationSerializer do
  subject { described_class.new(user_verification:).perform }

  let(:user_verification) { build(:user_verification) }

  it 'returns the serialized verification CSP type' do
    expect(subject[:type]).to eq(user_verification.credential_type)
  end

  it 'returns the serialized verification credential_id' do
    expect(subject[:credential_id]).to eq(user_verification.credential_identifier)
  end

  it 'returns the serialized verification locked status' do
    expect(subject[:locked]).to eq(user_verification.locked)
  end
end
