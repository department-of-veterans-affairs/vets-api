# frozen_string_literal: true

require 'rails_helper'
require 'mpi/messages/find_profile_by_facility'

describe MPI::Messages::FindProfileByFacility do
  describe '.perform' do
    subject do
      described_class.new(facility_id:, vista_id:).perform
    end

    let(:facility_id) { 'some-facility-id' }
    let(:vista_id) { 'some-vista-id' }
    let(:expected_identifier) { "#{vista_id}^PI^#{facility_id}^#{MPI::Constants::ACTIVE_VHA_IDENTIFIER}" }
    let(:idm_path) { 'env:Envelope/env:Body/idm:PRPA_IN201305UV02' }
    let(:parameter_list_path) { "#{idm_path}/controlActProcess/queryByParameter/parameterList" }

    shared_examples 'successfully built request' do
      it 'has a USDSVA extension with a uuid' do
        expect(subject).to match_at_path("#{idm_path}/id/@extension", /200VGOV-\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
      end

      it 'has a sender extension' do
        expect(subject).to eq_at_path("#{idm_path}/sender/device/id/@extension", '200VGOV')
      end

      it 'has a receiver extension' do
        expect(subject).to eq_at_path("#{idm_path}/receiver/device/id/@extension", '200M')
      end

      it 'has an identifier node' do
        expect(subject).to eq_at_path("#{parameter_list_path}/id/@root", MPI::Constants::VA_ROOT_OID)
        expect(subject).to eq_at_path("#{parameter_list_path}/id/@extension", expected_identifier)
      end
    end

    shared_examples 'validation error' do
      let(:expected_error) { MPI::Errors::ArgumentError }
      let(:expected_logger_message) do
        "[FindProfileByFacility] Failed to build request: #{expected_error_message}"
      end

      it 'raises an Argument Error with expected message and expected log' do
        expect(Rails.logger).to receive(:error).with(expected_logger_message)
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'successfully builds profile with vista and facility id' do
      it_behaves_like 'successfully built request'
    end

    context 'with raised exception' do
      let(:expected_exception) { StandardError }
      let(:expected_exception_message) { 'some-exception-message' }
      let(:expected_rails_log) { "[FindProfileByFacility] Failed to build request: #{expected_exception_message}" }

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
