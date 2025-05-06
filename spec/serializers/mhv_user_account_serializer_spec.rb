# frozen_string_literal: true

require 'rails_helper'

describe MHVUserAccountSerializer, type: :serializer do
  subject { serialize(mhv_user_account, serializer_class: described_class) }

  let(:mhv_user_account) { MHVUserAccount.new(mhv_response) }
  let(:mhv_response) do
    {
      user_profile_id: '123456',
      premium: true,
      champ_va: true,
      patient: true,
      sm_account_created: true,
      message: 'some-message'
    }
  end

  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq mhv_response[:user_profile_id]
  end

  it 'includes :user_profile_id' do
    expect(attributes['user_profile_id']).to eq mhv_response[:user_profile_id]
  end

  it 'includes :premium' do
    expect(attributes['premium']).to eq mhv_response[:premium]
  end

  it 'includes :champ_va' do
    expect(attributes['champ_va']).to eq mhv_response[:champ_va]
  end

  it 'includes :patient' do
    expect(attributes['patient']).to eq mhv_response[:patient]
  end

  it 'includes :sm_account_created' do
    expect(attributes['sm_account_created']).to eq mhv_response[:sm_account_created]
  end

  it 'includes :message' do
    expect(attributes['message']).to eq mhv_response[:message]
  end
end
