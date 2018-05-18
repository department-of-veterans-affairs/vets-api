# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::SubmitForm, type: :job do
  let(:user) { FactoryBot.create(:user, :loa3) }

  it 'submits the form and stores the returned claim_id' do
    client_stub = instance_double('EVSS::DisabilityCompensationForm::SubmitForm')
    allow(EVSS::CommonService).to receive(:new).with(auth_headers) { client_stub }
    expect(client_stub).to receive(:create_user_account).once
    described_class.new.perform(auth_headers)
  end
end
