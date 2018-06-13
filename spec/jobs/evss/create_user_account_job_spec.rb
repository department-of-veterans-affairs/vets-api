# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::CreateUserAccountJob, type: :job do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }
  let(:client_stub) { instance_double('EVSS::CommonService') }

  before { allow(EVSS::CommonService).to receive(:new).with(auth_headers) { client_stub } }
  it 'calls create_user_account EVSS API' do
    expect(client_stub).to receive(:create_user_account).once
    described_class.new.perform(auth_headers)
  end

  it 'rescues Common::Exceptions::BackendServiceException (raised for timeouts)' do
    allow(client_stub).to receive(:create_user_account).and_raise(Common::Exceptions::BackendServiceException)
    expect { described_class.new.perform(auth_headers) }.to raise_error(Sentry::IgnoredError)
  end
end
