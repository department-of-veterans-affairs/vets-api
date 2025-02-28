# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::V1::ApplicationController, type: :controller do
  let(:controller) { described_class.new }
  let(:with_gender) { false }

  before do
    allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_add_person_proxy).and_return(true)

    allow(controller).to receive(:header).with('X-VA-SSN').and_return('123456789')
    allow(controller).to receive(:header).with('X-VA-First-Name').and_return('Jake')
    allow(controller).to receive(:header).with('X-VA-Last-Name').and_return('Doe')
    allow(controller).to receive(:header).with('X-VA-Birth-Date').and_return('1967-05-06')

    controller.instance_variable_set(:@is_valid_ccg_flow, true)
    @veteran_instance = double('Veteran')
    allow(ClaimsApi::Veteran).to receive(:new).and_return(@veteran_instance)

    allow(@veteran_instance).to receive(:mpi_record?).and_return(true)
    allow(@veteran_instance).to receive(:edipi=)
    allow(@veteran_instance).to receive(:edipi_mpi)
    allow(@veteran_instance).to receive(:edipi)
    allow(@veteran_instance).to receive(:participant_id_mpi)
    allow(@veteran_instance).to receive(:participant_id=)
    allow(@veteran_instance).to receive(:participant_id)
    allow(@veteran_instance).to receive(:mpi_icn)
    allow(@veteran_instance).to receive(:icn=)
    allow(@veteran_instance).to receive(:icn)
  end

  describe '#veteran_from_headers' do
    it 'calls the recache method when building from headers' do
      allow(@veteran_instance).to receive(:recache_mpi_data)
      controller.send(:veteran_from_headers, with_gender:)

      expect(@veteran_instance).to have_received(:recache_mpi_data)
    end
  end
end
