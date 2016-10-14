# frozen_string_literal: true
require 'rails_helper'

RSpec.describe UserSerializer, type: :serializer do
  let(:user) { build :mvi_user }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:profile) { attributes['profile'] }
  let(:va_profile) { attributes['va_profile'] }

  subject { serialize(user, serializer_class: described_class) }

  it 'should not include ssn anywhere' do
    expect(attributes['ssn']).to be_nil
    expect(profile['ssn']).to be_nil
    expect(va_profile['ssn']).to be_nil
  end

  context 'inside "profile"' do
    # --- positive tests ---
    it 'should include email' do
      expect(profile['email']).to eq(user.email)
    end
    it 'should include first_name' do
      expect(profile['first_name']).to eq(user.first_name)
    end
    it 'should include middle_name' do
      expect(profile['middle_name']).to eq(user.middle_name)
    end
    it 'should include last_name' do
      expect(profile['last_name']).to eq(user.last_name)
    end
    it 'should include birth_date' do
      expect(Time.parse(profile['birth_date']).httpdate).to eq(user.birth_date.httpdate)
    end
    it 'should include gender' do
      expect(profile['gender']).to eq(user.gender)
    end
    it 'should include zip' do
      expect(profile['zip']).to eq(user.zip)
    end
    it 'should include last_signed_in' do
      expect(Time.parse(profile['last_signed_in']).httpdate).to eq(user.last_signed_in.httpdate)
    end

    # --- negative tests ---
    it 'should not include uuid in the profile' do
      expect(profile['uuid']).to be_nil
    end
    it 'should not include edipi in the profile' do
      expect(profile['edipi']).to be_nil
    end
    it 'should not include participant_id in the profile' do
      expect(profile['participant_id']).to be_nil
    end

  end

  context 'inside "va_profile"' do
    it 'should include birth_date' do
      expect(va_profile['birth_date']).to eq(user.mvi['birth_date'])
    end
    it 'should include family_name' do
      expect(va_profile['family_name']).to eq(user.mvi['family_name'])
    end
    it 'should include gender' do
      expect(va_profile['gender']).to eq(user.mvi['gender'])
    end
    it 'should include given_names' do
      expect(va_profile['given_names']).to eq(user.mvi['given_names'])
    end
    it 'should include status' do
      expect(va_profile['status']).to eq(user.mvi['status'])
    end
  end
end
