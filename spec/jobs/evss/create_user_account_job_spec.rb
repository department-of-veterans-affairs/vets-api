# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EVSS::CreateUserAccountJob, type: :job do
  let(:user) { FactoryGirl.create(:user, :loa3) }

  it 'calls create_user_account EVSS API' do
    client_stub = instance_double('EVSS::EVSSCommon::Service')
    expect(User).to receive(:find).with(user.uuid).and_return(user)
    allow(EVSS::EVSSCommon::Service).to receive(:new).with(user) { client_stub }
    expect(client_stub).to receive(:create_user_account).once
    described_class.new.perform(user.uuid)
  end
end
