# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/veteran_representative_service'

describe ClaimsApi::VeteranRepresentativeService do
  let(:header_params) do
    {
      external_uid: 'xUid',
      external_key: 'xKey'
    }
  end

  describe 'with a namespace param' do
    it 'does not raise ArgumentError' do
      service = described_class.new(**header_params)
      expect do
        service.send(:make_request, endpoint: 'endpoint', namespaces: { 'testspace' => '/test' },
                                    action: 'testAction',
                                    body: 'this is the body',
                                    key: 'ThisIsTheKey')
      end.not_to raise_error(ArgumentError)
    end
  end

  describe 'without the namespace param' do
    let(:params) { { ptcpnt_id: '123456' } }

    it 'raises ArgumentError' do
      service = described_class.new(**header_params)
      expect do
        service.send(:make_request, action: 'testAction', body: 'this is the body',
                                    key: 'ThisIsTheKey')
      end.to raise_error(ArgumentError)
    end
  end
end
