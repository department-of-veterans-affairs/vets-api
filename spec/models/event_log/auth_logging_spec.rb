# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Auth Logging', type: :model do
  let(:signup)  { create(:login_init_log, state: 'idme', data: { operation: 'signup' }) }
  let(:account) { create(:account) }
  let(:success) do
    create(:login_callback_log, state: 'success:signup', event_log_id: signup.id, account_id: account.id)
  end

  # let(:mhv)     { create(:login_init_log, state: 'myhealthevet') }
  # let(:failure) { create(:login_callback_log, state: 'failure', event_log_id: mhv.id, data: { error_code: 7 }) }
  # let(:dslogon) { create(:login_init_log, state: 'dslogon') }

  it 'logs successful signups' do
    expect(success.login_init_log.id).to eq(signup.id)
    expect(success.state).to eq('success:signup')
  end
end
