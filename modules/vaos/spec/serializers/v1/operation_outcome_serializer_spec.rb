# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/fixture_helper'

describe VAOS::V1::OperationOutcomeSerializer do
  describe 'json serialization' do
    context 'with a resource of Organization and a backend service exception' do
      let(:resource_type) { :Organization }
      let(:issue) { Common::Exceptions::BackendServiceException.new('VAOS_502', source: 'Klass') }
      let(:operation_outcome) { VAOS::V1::OperationOutcome.new(resource_type, issue) }

      it 'serializes the error in FHIR DSTU 2 format' do
        expect(VAOS::V1::OperationOutcomeSerializer.new(operation_outcome).serialized_json).to eq(
          read_fixture_file('operation_outcome_service_exception.json')
        )
      end
    end
  end
end
