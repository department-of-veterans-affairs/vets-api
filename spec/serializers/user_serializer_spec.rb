# frozen_string_literal: true
require 'rails_helper'

RSpec.describe UserSerializer, type: :serializer do
  let(:user) { build :loa3_user }
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
      expect(profile['birth_date']).to eq(user.birth_date)
    end
    it 'should include gender' do
      expect(profile['gender']).to eq(user.gender)
    end
    it 'should include zip' do
      expect(profile['zip']).to eq(user.zip)
    end
    it 'should include last_signed_in' do
      expect(Time.zone.parse(profile['last_signed_in']).httpdate).to eq(user.last_signed_in.httpdate)
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
    context 'when user.mvi is not nil' do
      it 'should include birth_date' do
        expect(va_profile['birth_date']).to eq(user.va_profile[:birth_date])
      end
      it 'should include family_name' do
        expect(va_profile['family_name']).to eq(user.va_profile[:family_name])
      end
      it 'should include gender' do
        expect(va_profile['gender']).to eq(user.va_profile[:gender])
      end
      it 'should include given_names' do
        expect(va_profile['given_names']).to eq(user.va_profile[:given_names])
      end
      it 'should include status' do
        expect(va_profile['status']).to eq('OK')
      end
    end

    context 'when user.mvi is nil' do
      let(:user) { build :user }
      let(:data) { JSON.parse(subject)['data'] }
      let(:attributes) { data['attributes'] }
      let(:va_profile) { attributes['va_profile'] }

      it 'returns va_profile as null' do
        expect(va_profile).to eq(
          'status' => 'NOT_AUTHORIZED'
        )
      end
    end

    context 'when user.mvi is not found' do
      before { stub_mvi_not_found }

      let(:data) { JSON.parse(subject)['data'] }
      let(:attributes) { data['attributes'] }
      let(:va_profile) { attributes['va_profile'] }

      it 'returns va_profile as null' do
        expect(va_profile).to eq(
          'status' => 'NOT_FOUND'
        )
      end
    end
  end
end
