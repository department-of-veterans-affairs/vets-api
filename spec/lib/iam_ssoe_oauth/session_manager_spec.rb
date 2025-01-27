# frozen_string_literal: true

require 'rails_helper'
require 'iam_ssoe_oauth/session_manager'

describe 'IAMSSOeOAuth::SessionManager' do
  let(:access_token) { 'ypXeAwQedpmAy5xFD2u5' }
  let(:session_manager) { IAMSSOeOAuth::SessionManager.new(access_token) }

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

      it 'last_signed_in is set and is a time' do
        expect(@user.last_signed_in).to be_a(Time)
      end
    end

    context 'with newly-authenticated token' do
      let(:dslogon_attrs) do
        build(:dslogon_level2_introspection_payload, fediam_authentication_instant: Time.current.utc.iso8601,
                                                     iat: 5.minutes.from_now.strftime('%s').to_i)
      end

      it 'increments the new OAuth session metric' do
        allow_any_instance_of(IAMSSOeOAuth::Service).to receive(:post_introspect).and_return(dslogon_attrs)
        allow(StatsD).to receive(:increment)
        @user = session_manager.find_or_create_user
        expect(StatsD).to have_received(:increment).with('iam_ssoe_oauth.session',
                                                         tags: ['type:new', 'credential:DSL'])
      end
    end

    context 'with refreshed token' do
      let(:idme_attrs) do
        build(:idme_loa3_introspection_payload, fediam_authentication_instant: Time.current.utc.iso8601,
                                                iat: 1.hour.from_now.strftime('%s').to_i)
      end

      it 'increments the new OAuth session metric' do
        allow_any_instance_of(IAMSSOeOAuth::Service).to receive(:post_introspect).and_return(idme_attrs)
        allow(StatsD).to receive(:increment)
        @user = session_manager.find_or_create_user
        expect(StatsD).to have_received(:increment).with('iam_ssoe_oauth.session',
                                                         tags: ['type:refresh', 'credential:IDME'])
      end
    end

    context 'with unparseable timestamps' do
      let(:mhv_attrs) do
        build(:mhv_premium_introspection_payload, fediam_authentication_instant: Time.current.utc.iso8601,
                                                  iat: 'garbage')
      end

      it 'increments the new OAuth session metric and defaults to refresh type' do
        allow_any_instance_of(IAMSSOeOAuth::Service).to receive(:post_introspect).and_return(mhv_attrs)
        allow(StatsD).to receive(:increment)
        @user = session_manager.find_or_create_user
        expect(StatsD).to have_received(:increment).with('iam_ssoe_oauth.session',
                                                         tags: ['type:refresh', 'credential:MHV'])
      end
    end

    context 'with a nil user' do
      it 'raises an unauthorized error' do
        allow(session_manager).to receive(:build_user).and_return(nil)
        VCR.use_cassette('iam_ssoe_oauth/introspect_active') do
          expect { session_manager.find_or_create_user }.to raise_error(Common::Exceptions::Unauthorized)
        end
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
