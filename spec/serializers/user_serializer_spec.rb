# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserSerializer do
  subject { serialize(pre_serialized_profile, serializer_class: described_class) }

  let(:user) { create(:user, :loa3) }
  let!(:in_progress_form) { create(:in_progress_form, user_uuid: user.uuid) }
  let(:pre_serialized_profile) { Users::Profile.new(user).pre_serialize }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  context 'when initialized with an object that cannot be called by each of the attributes' do
    it 'raises an error' do
      expect { serialize(user, serializer_class: described_class) }.to raise_error(NoMethodError)
    end
  end

  it 'returns serialized #services data' do
    expect(attributes['services']).to be_present
  end

  it 'returns serialized #account data' do
    expect(attributes['account']).to be_present
  end

  it 'returns serialized #profile data' do
    expect(attributes['profile']).to be_present
  end

  it 'returns serialized #va_profile data' do
    expect(attributes['va_profile']).to be_present
  end

  it 'returns serialized #veteran_status data' do
    expect(attributes['veteran_status']).to be_present
  end

  it 'returns serialized #in_progress_forms data' do
    expect(attributes['in_progress_forms']).to be_present
  end

  it 'returns serialized #prefills_available data' do
    expect(attributes['prefills_available']).to be_present
  end

  it 'returns serialized #vet360_contact_information data' do
    expect(attributes['vet360_contact_information']).to be_present
  end

  it 'returns serialized #session data' do
    expect(attributes['session']).to be_present
  end
end
