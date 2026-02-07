# frozen_string_literal: true

require 'rails_helper'
require 'mpi/messages/find_profile_by_identifier'

describe MPI::Messages::FindProfileByIdentifier do
  describe '.perform' do
    subject do
      described_class.new(identifier:, identifier_type:, search_type:, view_type:).perform
    end

    let(:identifier) { 'some-identifier' }
    let(:identifier_type) { MPI::Constants::QUERY_IDENTIFIERS.first }
    let(:expected_identifier) { identifier }
    let(:search_type) { MPI::Constants::SEARCH_TYPES.first }
    let(:view_type) { MPI::Constants::VIEW_TYPES.first }
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

      it 'has a query by parameter node with search type' do
        expect(subject).to eq_at_path("#{idm_path}/controlActProcess/queryByParameter/modifyCode/@code", search_type)
      end

      it 'has an identifier node' do
        expect(subject).to eq_at_path("#{parameter_list_path}/id/@root", MPI::Constants::VA_ROOT_OID)
        expect(subject).to eq_at_path("#{parameter_list_path}/id/@extension", expected_identifier)
      end
    end

    shared_examples 'validation error' do
      let(:expected_error) { MPI::Errors::ArgumentError }
      let(:expected_logger_message) do
        "[FindProfileByIdentifier] Failed to build request: #{expected_error_message}"
      end

      it 'raises an Argument Error with expected message and expected log' do
        expect(Rails.logger).to receive(:error).with(expected_logger_message)
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when identifier type is ICN' do
      let(:identifier_type) { MPI::Constants::ICN }
      let(:expected_identifier) { identifier }

      it_behaves_like 'successfully built request'
    end

    context 'when identifier type is IDME_UUID' do
      let(:identifier_type) { MPI::Constants::IDME_UUID }
      let(:expected_identifier) { "#{identifier}^#{MPI::Constants::IDME_FULL_IDENTIFIER}" }

      it_behaves_like 'successfully built request'
    end

    context 'when identifier type is LOGINGOV_UUID' do
      let(:identifier_type) { MPI::Constants::LOGINGOV_UUID }
      let(:expected_identifier) { "#{identifier}^#{MPI::Constants::LOGINGOV_FULL_IDENTIFIER}" }

      it_behaves_like 'successfully built request'
    end

    context 'when identifier type is MHV_UUID' do
      let(:identifier_type) { MPI::Constants::MHV_UUID }
      let(:expected_identifier) { "#{identifier}^#{MPI::Constants::MHV_FULL_IDENTIFIER}" }

      it_behaves_like 'successfully built request'
    end

    context 'when identifier type is an arbitrary value' do
      let(:identifier_type) { 'some-identifier-type' }
      let(:expected_error_message) { "Identifier type is not supported, identifier_type=#{identifier_type}" }

      it_behaves_like 'validation error'
    end

    context 'when view type is an arbitrary value' do
      let(:view_type) { 'some-view-type' }
      let(:expected_error_message) { "View type is not supported, view_type=#{view_type}" }

      it_behaves_like 'validation error'
    end

    context 'when identifier type is ICN and view type is correlation view' do
      let(:identifier_type) { MPI::Constants::ICN }
      let(:view_type) { MPI::Constants::CORRELATION_VIEW }
      let(:expected_error_message) { "ICN searches only support the primary view, view=#{view_type}" }

      it_behaves_like 'validation error'
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
