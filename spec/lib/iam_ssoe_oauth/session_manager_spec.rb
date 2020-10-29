# frozen_string_literal: true

require 'rails_helper'
require 'iam_ssoe_oauth/session_manager'

describe 'IAMSSOeOAuth::SessionManager' do
  let(:access_token) { 'ypXeAwQedpmAy5xFD2u5' }
  let(:session_manager) { IAMSSOeOAuth::SessionManager.new(access_token) }

  before do
    allow(IAMSSOeOAuth::Configuration.instance).to receive(:ssl_cert)
      .and_return(instance_double('OpenSSL::X509::Certificate'))
    allow(IAMSSOeOAuth::Configuration.instance).to receive(:ssl_key)
      .and_return(instance_double('OpenSSL::PKey::RSA'))
  end

  describe '#find_or_create_user' do
    context 'with a valid access token' do
      before do
        VCR.use_cassette('iam_ssoe_oauth/introspect_active') do
          @user = session_manager.find_or_create_user
        end
      end

      it 'creates a session object' do
        expect(IAMSession.find(access_token)).not_to be_nil
      end

      it 'creates a user with a uuid' do
        expect(@user.uuid).not_to be_nil
      end

      it 'creates a user identity' do
        expect(@user.identity).not_to be_nil
      end
    end
  end

  describe '#logout' do
    context 'with a signed in user who logs out' do
      before do
        VCR.use_cassette('iam_ssoe_oauth/introspect_active') do
          @user = session_manager.find_or_create_user
        end

        VCR.use_cassette('iam_ssoe_oauth/revoke_200') do
          session_manager.logout
        end
      end

      it 'destroys the session in redis' do
        expect(IAMSession.find(access_token)).to be_nil
      end

      it 'destroys the user object in redis' do
        expect(IAMUser.find(@user.uuid)).to be_nil
      end

      it 'destroys the user identity in redis' do
        expect(IAMUserIdentity.find(@user.uuid)).to be_nil
      end
    end
  end
end
