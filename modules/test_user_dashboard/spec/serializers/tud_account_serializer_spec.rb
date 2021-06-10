# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TestUserDashboard::TudAccountSerializer, type: :serializer do
  subject { serialize(tud_account, serializer_class: described_class) }

  let(:tud_account) { create(:tud_account) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'returns serialized #first_name data' do
    expect(attributes['first_name']).to be_present
  end

  it 'returns serialized #last_name data' do
    expect(attributes['last_name']).to be_present
  end

  it 'returns serialized #email data' do
    expect(attributes['email']).to be_present
  end

  it 'returns serialized #gender data' do
    expect(attributes['gender']).to be_present
  end
end
