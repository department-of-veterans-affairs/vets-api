# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VRE::Ch31CaseMilestones::Service do
  let(:service) { described_class.new(icn) }
  let(:icn) { '1012667145V762142' }
  let(:error_klass) { Common::Exceptions::BackendServiceException }

  describe '#initialize' do
    it 'assigns ICN value if present' do
      expect(service.instance_variable_get(:@icn)).to eq(icn)
    end

    it 'raises Forbidden error if icn missing' do
      expect { described_class.new(nil) }.to raise_error(Common::Exceptions::Forbidden, 'ICN is required')
    end

    it 'raises Forbidden error if icn is blank' do
      expect { described_class.new('') }.to raise_error(Common::Exceptions::Forbidden, 'ICN is required')
    end
  end

  describe '#update_milestones' do
    let(:raw_response) { instance_double(Faraday::Response, status: 200) }
    let(:response) { instance_double(VRE::Ch31CaseMilestones::Response) }
    let(:url) { "#{Settings.res.base_url}/suite/webapi/update-ch31-milestone-status" }
    let(:headers) { { 'Appian-API-Key' => Settings.res.ch_31_case_milestones.api_key.to_s } }
    let(:milestone_params) do
      {
        milestones: [
          {
            milestoneType: 'ORIENTATION_COMPLETION',
            isMilestoneCompleted: true,
            milestoneCompletionDate: '2025-01-15',
            milestoneSubmissionUser: 'john.smith'
          }
        ]
      }
    end
    let(:payload) { { icn:, milestones: milestone_params[:milestones] } }
    let(:request_params) { [:post, url, payload.to_json, headers] }

    context 'when successful' do
      it 'sends payload with icn and milestones to RES' do
        allow(service).to receive(:perform).with(*request_params).and_return(raw_response)
        allow(VRE::Ch31CaseMilestones::Response).to receive(:new)
          .with(raw_response.status, raw_response)
          .and_return(response)
        service.update_milestones(milestone_params)
        expect(service).to have_received(:perform).with(*request_params)
        expect(VRE::Ch31CaseMilestones::Response).to have_received(:new)
          .with(raw_response.status, raw_response)
      end
    end

    context 'when unsuccessful' do
      let(:key) { 'RES_CH31_CASE_MILESTONES_403' }
      let(:response_values) { { status: 403, detail: nil, code: key, source: nil } }
      let(:message) { 'ICN is required' }
      let(:error) { error_klass.new(key, response_values, 403, 'errorMessageList' => [message]) }

      before { allow(service).to receive(:send_to_res).and_raise(error) }

      it 'logs and raises error' do
        allow(Rails.logger).to receive(:error)
        expect { service.update_milestones(milestone_params) }.to raise_error(error_klass)
        expect(Rails.logger).to have_received(:error)
          .with("Failed to update Ch. 31 case milestones: #{[message]}", backtrace: error.backtrace)
      end
    end

    context 'when RES service unavailable with specific error code' do
      let(:key) { 'RES_CH31_CASE_MILESTONES_500' }
      let(:response_values) { { status: 500, detail: nil, code: key, source: nil } }
      let(:message) { described_class::SERVICE_UNAVAILABLE_ERROR }
      let(:error) { error_klass.new(key, response_values, 500, 'error' => message) }

      before do
        allow(service).to receive(:send_to_res).and_raise(error)
      end

      it 'logs and remaps to RES_CH31_CASE_MILESTONES_503 error' do
        allow(Rails.logger).to receive(:error)
        expect { service.update_milestones(milestone_params) }.to raise_error(error_klass) do |raised|
          expect(raised.key).to eq('RES_CH31_CASE_MILESTONES_503')
          expect(raised.response_values).to eq(response_values)
        end
        expect(Rails.logger).to have_received(:error)
          .with("Failed to update Ch. 31 case milestones: #{message}", backtrace: error.backtrace)
      end
    end

    context 'when RES service returns 500 with different error code' do
      let(:key) { 'RES_CH31_CASE_MILESTONES_500' }
      let(:response_values) { { status: 500, detail: nil, code: key, source: nil } }
      let(:message) { 'SOME-OTHER-ERROR-CODE' }
      let(:error) { error_klass.new(key, response_values, 500, 'error' => message) }

      before do
        allow(service).to receive(:send_to_res).and_raise(error)
      end

      it 'logs and raises original error without remapping' do
        allow(Rails.logger).to receive(:error)
        expect { service.update_milestones(milestone_params) }.to raise_error(error_klass) do |raised|
          expect(raised.key).to eq(key)
          expect(raised.key).not_to eq('RES_CH31_CASE_MILESTONES_503')
        end
        expect(Rails.logger).to have_received(:error)
          .with("Failed to update Ch. 31 case milestones: #{message}", backtrace: error.backtrace)
      end
    end
  end
end
