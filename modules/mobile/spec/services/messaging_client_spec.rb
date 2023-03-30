# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::Messaging::Client do
  describe 'configuration override' do
    it 'uses alternate app_token' do
      with_settings(Settings.mhv_mobile.sm, app_token: 'TestToken') do
        stub_request(:get, /session/).with(headers: { 'appToken' => 'TestToken' })
                                     .to_return(status: 200, headers: { 'Token' => 'abcd1234z' })
        svc = Mobile::V0::Messaging::Client.new(session: { user_id: '10616687' })
        svc.authenticate
        expect(a_request(:get, /session/).with(headers: { 'appToken' => 'TestToken' }))
          .to have_been_made.once
      end
    end

    it 'uses alternate session store' do
      user_id = '10616687'
      key = "#{REDIS_CONFIG[:sm_store_mobile][:namespace]}:#{user_id}"
      with_settings(Settings.mhv_mobile.sm, app_token: 'TestToken') do
        stub_request(:get, /session/).with(headers: { 'appToken' => 'TestToken' })
                                     .to_return(status: 200, headers: { 'Token' => 'abcd1234z' })
        svc = Mobile::V0::Messaging::Client.new(session: { user_id: })
        svc.authenticate
        expect(Redis.new.get(key)).to be_truthy
      end
    end
  end
end
