# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::IntrospectSerializer do
  subject(:serialized_data) { serialize(access_token, serializer_class: described_class) }

  let(:access_token) { create(:access_token) }
  let(:attributes) { JSON.parse(serialized_data)['data']['attributes'] }

  shared_examples 'serializes attribute' do |serialized_attribute, attribute|
    it "returns the value for #{attribute}" do
      expect(attributes[serialized_attribute.to_s]).to eq(access_token.public_send(attribute))
    end
  end

  shared_examples 'serializes datetime attribute' do |serialized_attribute, attribute|
    it "returns the value for #{attribute}" do
      expect(attributes[serialized_attribute.to_s]).to eq(access_token.public_send(attribute).to_i)
    end
  end

  describe '#active' do
    context 'when access token is not expired' do
      it 'returns data with #active set to true' do
        expect(attributes['active']).to be_truthy
      end
    end

    context 'when access token is expired' do
      let(:access_token) { create(:access_token, expiration_time: 1.minute.ago) }

      it 'returns data with #active set to false' do
        expect(attributes['active']).to be_falsey
      end
    end
  end

  describe '#anti_csrf_token' do
    include_examples 'serializes attribute', :anti_csrf_token, :anti_csrf_token
  end

  describe '#aud' do
    include_examples 'serializes attribute', :aud, :audience
  end

  describe '#client_id' do
    include_examples 'serializes attribute', :client_id, :client_id
  end

  describe '#exp' do
    include_examples 'serializes datetime attribute', :exp, :expiration_time
  end

  describe '#iat' do
    include_examples 'serializes datetime attribute', :iat, :created_time
  end

  describe '#iss' do
    it 'serializes attribute iss' do
      expect(attributes['iss']).to eq(SignIn::Constants::AccessToken::ISSUER)
    end
  end

  describe '#jti' do
    include_examples 'serializes attribute', :jti, :uuid
  end

  describe '#last_regeneration_time' do
    include_examples 'serializes datetime attribute', :last_regeneration_time, :last_regeneration_time
  end

  describe '#parent_refresh_token_hash' do
    include_examples 'serializes attribute', :parent_refresh_token_hash, :parent_refresh_token_hash
  end

  describe '#refresh_token_hash' do
    include_examples 'serializes attribute', :refresh_token_hash, :refresh_token_hash
  end

  describe '#session_handle' do
    include_examples 'serializes attribute', :session_handle, :session_handle
  end

  describe '#sub' do
    include_examples 'serializes attribute', :sub, :user_uuid
  end

  describe '#user_attributes' do
    context 'when access token does not include user attributes' do
      it 'returns empty #user_attributes data' do
        expect(attributes['user_attributes']).to be_blank
      end
    end

    context 'when access token includes user attributes' do
      let(:access_token) { create(:access_token, client_id: client_config.client_id, user_attributes:) }
      let(:client_config) { create(:client_config, access_token_attributes: %w[first_name last_name]) }
      let(:user_attributes) { { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name } }

      it 'returns serialized #first_name data' do
        expect(attributes['user_attributes']['first_name']).to eq(user_attributes[:first_name])
      end

      it 'returns serialized #last_name data' do
        expect(attributes['user_attributes']['last_name']).to eq(user_attributes[:last_name])
      end
    end
  end

  describe '#version' do
    include_examples 'serializes attribute', :version, :version
  end
end
