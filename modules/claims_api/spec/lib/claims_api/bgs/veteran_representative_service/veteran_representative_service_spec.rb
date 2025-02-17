# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/veteran_representative_service'

describe ClaimsApi::VeteranRepresentativeService do
  subject { described_class.new(external_uid: 'xUid', external_key: 'xKey') }

  describe 'with a namespace param' do
    it 'does not raise ArgumentError' do
      expect do
        subject.send(:make_request, endpoint: 'endpoint', namespaces: { 'testspace' => '/test' },
                                    action: 'testAction',
                                    body: 'this is the body',
                                    key: 'ThisIsTheKey')
      end.not_to raise_error(ArgumentError)
    end
  end

  describe 'without the namespace param' do
    let(:params) { { ptcpnt_id: '123456' } }

    it 'raises ArgumentError' do
      expect do
        subject.send(:make_request, action: 'testAction', body: 'this is the body',
                                    key: 'ThisIsTheKey')
      end.to raise_error(ArgumentError)
    end
  end
end
