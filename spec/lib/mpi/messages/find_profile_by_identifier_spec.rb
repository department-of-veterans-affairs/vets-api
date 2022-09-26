# frozen_string_literal: true

require 'rails_helper'

describe MPI::Messages::FindProfileByIdentifier do
  describe '.perform' do
    subject { described_class.new(identifier: icn).perform }

    let(:icn) { 'fake-icn-number' }
    let(:idm_path) { 'env:Envelope/env:Body/idm:PRPA_IN201305UV02' }
    let(:parameter_list_path) { "#{idm_path}/controlActProcess/queryByParameter/parameterList" }

    it 'has a USDSVA extension with a uuid' do
      expect(subject).to match_at_path("#{idm_path}/id/@extension", /200VGOV-\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
    end

    it 'has a sender extension' do
      expect(subject).to eq_at_path("#{idm_path}/sender/device/id/@extension", '200VGOV')
    end

    it 'has a receiver extension' do
      expect(subject).to eq_at_path("#{idm_path}/receiver/device/id/@extension", '200M')
    end

    it 'does not have a dataEnterer node' do
      expect(subject).not_to eq_at_path("#{idm_path}/controlActProcess/dataEnterer/@typeCode", 'ENT')
    end

    it 'has an icn/id node' do
      expect(subject).to eq_at_path("#{parameter_list_path}/id/@root", MPI::Constants::VA_ROOT_OID)
      expect(subject).to eq_at_path("#{parameter_list_path}/id/@extension", icn)
    end

    context 'with raised exception' do
      let(:expected_exception) { StandardError }
      let(:expected_exception_message) { 'some-exception-message' }
      let(:expected_rails_log) { "[FindProfileByIdentifier] Failed to build request: #{expected_exception_message}" }

      before do
        allow(MPI::Messages::RequestBuilder).to receive(:new).and_raise(expected_exception, expected_exception_message)
      end

      it 'raises expected exception and logs an error message to rails' do
        expect(Rails.logger).to receive(:error).with(expected_rails_log)
        expect { subject }.to raise_error(expected_exception)
      end
    end
  end
end
