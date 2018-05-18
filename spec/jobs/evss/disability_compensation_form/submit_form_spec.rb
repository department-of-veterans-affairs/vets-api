# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::SubmitForm, type: :job do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:service) { instance_double('EVSS::DisabilityCompensationForm::Service') }
  let(:form_data) { { data: "I'm a form" }.to_json }

  it 'submits the form and stores the returned claim_id' do
    service = instance_double('EVSS::DisabilityCompensationForm::Service')
    service(:new).with(user) { service }
    allow(service).to receive(:submit_form).with(form_data).and_return(600130094)
    described_class.new.perform(auth_headers)
  end
end
