# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/demographics/gender_identity_response'

describe GenderIdentitySerializer, type: :serializer do
  subject { serialize(gender_identity_response, serializer_class: described_class) }

  let(:gender_identity) { VAProfile::Models::GenderIdentity.new(code: 'F', name: 'Female') }
  let(:gender_identity_response) { VAProfile::Demographics::GenderIdentityResponse.new(200, gender_identity:) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :gender_identity' do
    gender_identity_attributes = gender_identity_response.gender_identity.attributes.deep_stringify_keys
    expect(attributes['gender_identity']).to eq gender_identity_attributes
  end
end
