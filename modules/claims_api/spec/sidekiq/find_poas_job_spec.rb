# frozen_string_literal: true

require 'rails_helper'

Rspec.describe ClaimsApi::FindPoasJob, type: :job do
  subject { described_class }

  describe '#perform' do
    before do
      allow(ClaimsApi::Logger).to receive(:log)
    end

    context 'when the response is an array with at least one item' do
      it 'logs that the POAs were found' do
        allow_any_instance_of(ClaimsApi::FindPOAsService).to receive(:response).and_return([{ legacy_poa_cd: '002',
                                                                                              ptcpnt_id: '46004' }])
        expect(ClaimsApi::Logger).to receive(:log).with('find_poas_job', detail: 'Find POAs cached')
        subject.new.perform
      end
    end

    context 'when the response is not an array' do
      it 'logs that the POAs were not found' do
        allow_any_instance_of(ClaimsApi::FindPOAsService).to receive(:response).and_return('some error')
        expect(ClaimsApi::Logger).to receive(:log).with('find_poas_job', detail: 'Find POAs failed')
        subject.new.perform
      end
    end

    context 'when the response is an empty array' do
      it 'logs that the POAs were not found' do
        allow_any_instance_of(ClaimsApi::FindPOAsService).to receive(:response).and_return([])
        expect(ClaimsApi::Logger).to receive(:log).with('find_poas_job', detail: 'Find POAs failed')
        subject.new.perform
      end
    end
  end
end
