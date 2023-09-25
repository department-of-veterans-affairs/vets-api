# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/phr_mgr/client'
Sidekiq::Testing.fake!

RSpec.describe MHV::PhrUpdateJob, type: :job do
  describe '#perform' do
    let(:icn) { 'some_icn' }
    let(:mhv_correlation_id) { 'some_id' }
    let(:phr_client_instance) { instance_double(PHRMgr::Client) }

    before do
      allow(PHRMgr::Client).to receive(:new).and_return(phr_client_instance)
      allow(phr_client_instance).to receive(:post_phrmgr_refresh)
    end

    context 'when the user is an MHV user' do
      it 'calls the PHR refresh' do
        described_class.new.perform(icn, mhv_correlation_id)
        expect(phr_client_instance).to have_received(:post_phrmgr_refresh).with(icn)
      end
    end

    context 'when the user is not an MHV user' do
      let(:mhv_correlation_id) { nil }

      it 'does not call the PHR refresh' do
        described_class.new.perform(icn, mhv_correlation_id)
        expect(phr_client_instance).not_to have_received(:post_phrmgr_refresh)
      end
    end

    context 'when an error occurs' do
      it 'logs the error' do
        allow(Rails.logger).to receive(:error)
        allow(phr_client_instance).to receive(:post_phrmgr_refresh).and_raise(StandardError, 'some error')
        described_class.new.perform(icn, mhv_correlation_id)
        expect(Rails.logger).to have_received(:error).with(match(/MHV PHR refresh failed: some error/),
                                                           instance_of(StandardError))
      end
    end
  end
end
