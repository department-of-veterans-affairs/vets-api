# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EVSS::CreateUserAccountJob, type: :job do
  include ActiveJob::TestHelper
  let(:user) { User.sample_claimant }
  let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }

  it 'calls create_user_account EVSS API' do
    client_stub = instance_double('EVSS::CommonService')
    allow(EVSS::CommonService).to receive(:new).with(auth_headers) { client_stub }
    expect(client_stub).to receive(:create_user_account).once
    described_class.perform_now(auth_headers)
  end
end
