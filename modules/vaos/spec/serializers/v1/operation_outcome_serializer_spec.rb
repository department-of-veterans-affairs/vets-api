# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/fixture_helper'

describe VAOS::V1::OperationOutcomeSerializer do
  describe 'json serialization' do
    let(:resource_type) { :Organization }
    let(:id) { '987654' }

    context 'with a resource of Organization and a backend service exception' do
      let(:issue) { Common::Exceptions::BackendServiceException.new('VAOS_502', source: 'Klass') }
      let(:operation_outcome) { VAOS::V1::OperationOutcome.new(resource_type:, id:, issue:) }

      it 'serializes the error in FHIR DSTU 2 format' do
        expect(VAOS::V1::OperationOutcomeSerializer.new(operation_outcome).serialized_json).to eq(
          read_fixture_file('operation_outcome_service_exception.json')
        )
      end
    end

    context 'with a resource of Organization and an unexpected error (vets-api 500)' do
      let(:issue) { NoMethodError.new("undefined method 'to_ary' for \"hello\":String") }
      let(:operation_outcome) { VAOS::V1::OperationOutcome.new(resource_type:, id:, issue:) }

      it 'serializes the error in FHIR DSTU 2 format' do
        expect(VAOS::V1::OperationOutcomeSerializer.new(operation_outcome).serialized_json).to eq(
          read_fixture_file('operation_outcome_system_exception.json')
        )
      end
    end

    context 'with an informational message' do
      let(:issue) { { detail: 'Additional information may be found in the conformance doc' } }
      let(:operation_outcome) { VAOS::V1::OperationOutcome.new(resource_type:, issue:) }

      it 'serializes the error in FHIR DSTU 2 format' do
        expect(VAOS::V1::OperationOutcomeSerializer.new(operation_outcome).serialized_json).to eq(
          read_fixture_file('operation_outcome_information.json')
        )
      end
    end
  end
end
