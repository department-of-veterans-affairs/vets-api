# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserSerializer do
  subject { serialize(pre_serialized_profile, serializer_class: described_class) }

  let(:user) { create(:user, :loa3) }
  let!(:in_progress_form) { create(:in_progress_form, user_uuid: user.uuid) }
  let(:pre_serialized_profile) { Users::Profile.new(user).pre_serialize }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  before do
    create(:user_verification, idme_uuid: user.idme_uuid)
  end

  context 'when initialized with an object that cannot be called by each of the attributes' do
    it 'raises an error' do
      expect { serialize(user, serializer_class: described_class) }.to raise_error(NoMethodError)
    end
  end

  it 'returns serialized #services data' do
    expect(attributes['services']).to eq pre_serialized_profile.services
  end

  it 'returns serialized #account data' do
    expect(attributes['account']).to eq pre_serialized_profile.account.deep_stringify_keys
  end

  it 'returns serialized #profile data' do
    expect(attributes['profile']).to eq JSON.parse(pre_serialized_profile.profile.to_json)
  end

  it 'returns serialized #va_profile data' do
    expect(attributes['va_profile']).to eq pre_serialized_profile.va_profile.deep_stringify_keys
  end

  it 'returns serialized #onboarding data' do
    expect(attributes['onboarding']).to eq pre_serialized_profile.onboarding.deep_stringify_keys
  end

  it 'returns serialized #veteran_status data' do
    VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: %i[body],
                                                                                allow_playback_repeats: true) do
      expect(attributes['veteran_status']).to eq pre_serialized_profile.veteran_status.deep_stringify_keys
    end
  end

  it 'returns serialized #in_progress_forms data' do
    in_progress_form = pre_serialized_profile.in_progress_forms.first.deep_stringify_keys
    expect(attributes['in_progress_forms'].first).to eq in_progress_form
  end

  it 'returns serialized #prefills_available data' do
    expect(attributes['prefills_available']).to eq pre_serialized_profile.prefills_available
  end

  it 'returns serialized #vet360_contact_information data' do
    vet360_contact_information = JSON.parse(pre_serialized_profile.vet360_contact_information.to_json)
    expect(attributes['vet360_contact_information']).to eq vet360_contact_information
  end

  it 'returns serialized #session data' do
    expect(attributes['session']).to eq pre_serialized_profile.session.deep_stringify_keys
  end
end
