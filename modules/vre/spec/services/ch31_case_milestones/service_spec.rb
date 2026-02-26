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

    it 'raises ParameterMissing error if icn missing' do
      expect { described_class.new(nil) }.to raise_error(Common::Exceptions::ParameterMissing)
    end

    it 'raises ParameterMissing error if icn is blank' do
      expect { described_class.new('') }.to raise_error(Common::Exceptions::ParameterMissing)
    end
  end

  describe '#update_milestones' do
    let(:raw_response) { instance_double(Faraday::Response, status: 200) }
    let(:response) { instance_double(VRE::Ch31CaseMilestones::Response) }
    let(:url) { "#{Settings.res.base_url}/suite/webapi/update-ch31-milestone-status" }
    let(:headers) { { 'Appian-API-Key' => Settings.res.api_key.to_s } }
    let(:milestone_params) do
      {
        milestones: [
          {
            milestoneType: 'ORIENTATION_COMPLETION',
            isMilestoneCompleted: true,
            milestoneCompletionDate: '2025-01-15',
            milestoneSubmissionUser: 'john.smith',
            postpone: false
          }
        ]
      }
    end
    let(:payload) { { icn:, milestones: milestone_params[:milestones] } }
    let(:request_params) { [:post, url, payload.to_json, headers] }

    context 'when successful' do
      before do
        allow(service).to receive(:perform).with(*request_params).and_return(raw_response)
        allow(VRE::Ch31CaseMilestones::Response).to receive(:new)
          .with(raw_response.status, raw_response)
          .and_return(response)
      end

      it 'sends payload with icn and milestones to RES' do
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

    # context 'when RES service unavailable with specific error code' do
    #   let(:key) { 'RES_CH31_CASE_MILESTONES_500' }
    #   let(:response_values) { { status: 500, detail: nil, code: key, source: nil } }
    #   let(:message) { described_class::SERVICE_UNAVAILABLE_ERROR }
    #   let(:error) { error_klass.new(key, response_values, 500, 'error' => message) }

    #   before do
    #     allow(service).to receive(:send_to_res).and_raise(error)
    #   end

    #   it 'logs and remaps to RES_CH31_CASE_MILESTONES_503 error' do
    #     allow(Rails.logger).to receive(:error)
    #     expect { service.update_milestones(milestone_params) }.to raise_error(error_klass) do |raised|
    #       expect(raised.key).to eq('RES_CH31_CASE_MILESTONES_503')
    #       expect(raised.response_values).to eq(response_values)
    #     end
    #     expect(Rails.logger).to have_received(:error)
    #       .with("Failed to update Ch. 31 case milestones: #{message}", backtrace: error.backtrace)
    #   end
    # end

    context 'when RES service returns 500 error' do
      let(:key) { 'RES_CH31_CASE_MILESTONES_500' }
      let(:response_values) { { status: 500, detail: nil, code: key, source: nil } }
      let(:message) { 'Internal Server Error' }
      let(:error) { error_klass.new(key, response_values, 500, 'error' => message) }

      before do
        allow(service).to receive(:send_to_res).and_raise(error)
      end

      it 'logs and raises the error' do
        allow(Rails.logger).to receive(:error)
        expect { service.update_milestones(milestone_params) }.to raise_error(error_klass) do |raised|
          expect(raised.key).to eq(key)
        end
        expect(Rails.logger).to have_received(:error)
          .with("Failed to update Ch. 31 case milestones: #{message}", backtrace: error.backtrace)
      end
    end
  end
end
