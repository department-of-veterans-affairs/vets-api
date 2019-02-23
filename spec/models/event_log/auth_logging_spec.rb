# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Auth Logging', type: :model do
  let(:signup)  { create(:login_init_log, state: 'idme', data: { operation: 'signup' }) }
  let(:account) { create(:account) }
  let(:success) do
    create(:login_callback_log, state: 'success:signup', event_log_id: signup.id, account_id: account.id)
  end

  let(:mhv)     { create(:login_init_log, state: 'myhealthevet') }
  let(:failure) do
    create(:login_callback_log, state: 'failure:myhealthevet', event_log_id: mhv.id, data: { error_code: 7 })
  end

  let(:dslogon) { create(:login_init_log, state: 'dslogon') }

  let(:logout_init) { create(:logout_init_log) }
  let(:logout_callback) { create(:logout_callback_log, event_log_id: logout_init.id) }

  it 'logs successful signups' do
    expect(success.login_init_log.id).to eq(signup.id)
    expect(success.state).to eq('success:signup')
  end

  it 'logs failed mhv' do
    expect(failure.login_init_log.id).to eq(mhv.id)
    expect(failure.state).to eq('failure:myhealthevet')
  end

  it 'logs dslogon without a callback being returned' do
    expect(dslogon.login_callback_log).to be_nil
  end

  it 'logs logout success' do
    expect(logout_callback.logout_init_log.id).to eq(logout_init.id)
  end
end
