# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::SubmitForm686cJob, type: :job do
  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:all_flows_payload) { FactoryBot.build(:form_686c_674) }

  it 'calls #submit for 686c submission' do
    client_stub = instance_double('BGS::Form686c')
    allow(BGS::Form686c).to receive(:new).with(user) { client_stub }
    expect(client_stub).to receive(:submit).once
    described_class.new.perform(user, all_flows_payload)
  end
end