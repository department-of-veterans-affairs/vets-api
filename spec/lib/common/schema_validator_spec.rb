# frozen_string_literal: true

require 'rails_helper'
require 'common/schema_validator'

describe Common::SchemaValidator do
  let(:response_body) do
    { 'data' =>
    [{ 'id' => '121133',
       'identifier' => [{ 'system' => 'http://med.va.gov/fhir/urn/vaos/vista/983/appointment/id',
                          'value' => '999;20220827.094500' }],
       'kind' => 'clinic',
       'status' => 'cancelled',
       'service_type' => 'optometry',
       'patient_icn' => '1012846043V576341',
       'location_id' => '983',
       'clinic' => '455',
       'start' => '2022-08-27T10:30:00Z',
       'cancelation_reason' =>
       { 'coding' =>
         [{ 'system' => 'http://terminology.hl7.org/CodeSystem/appointment-cancellation-reason',
            'code' => 'pat',
            'display' => 'The appointment was cancelled by the patient' }] },
       'cancellable' => false,
       'extension' => { 'cc_location' => { 'address' => {} },
                        'vista_status' => ['CANCELLED BY PATIENT', 'FUTURE'] } }] }
  end

  context 'when response matches schema' do
    it 'does not log an error' do
      expect(Rails.logger).not_to receive(:error)
      Common::SchemaValidator.new(response_body.to_json, 'modules/vaos/app/schemas/appointments.json').validate
    end
  end

  context 'when response has additional attributes' do
    it 'logs an error with details' do
      response_body['data'].first['foo'] = 'bar'
      expect(Rails.logger).to receive(:error).with(
        'Schema discrepancy found',
        {
          details: ["The property '#/data/0' contains additional properties [\"foo\"] outside of the schema when none \
are allowed in schema ce30c58b-2863-5d25-ace5-b775337a4e2c"],
          response: response_body.to_json,
          schema_file: 'modules/vaos/app/schemas/appointments.json'
        }
      )
      Common::SchemaValidator.new(response_body.to_json, 'modules/vaos/app/schemas/appointments.json').validate
    end
  end

  context 'when response is missing required attributes' do
    it 'logs an error with details' do
      modified_record = response_body['data'].first.except('id')
      response_body['data'][0] = modified_record
      expect(Rails.logger).to receive(:error).with(
        'Schema discrepancy found',
        { details:
          ["The property '#/data/0' did not contain a required property of 'id' in schema \
ce30c58b-2863-5d25-ace5-b775337a4e2c"],
          response: response_body.to_json,
          schema_file: 'modules/vaos/app/schemas/appointments.json' }
      )

      Common::SchemaValidator.new(response_body.to_json, 'modules/vaos/app/schemas/appointments.json').validate
    end
  end

  context 'when nested property is missing required properties' do
    it 'logs an error with details' do
      response_body['data'][0]['cancelation_reason']['coding'] = [{
        code: 'pat',
        display: 'The appointment was cancelled by the patient'
      }]
      expect(Rails.logger).to receive(:error).with(
        'Schema discrepancy found',
        { details:
          ["The property '#/data/0/cancelation_reason/coding/0' did not contain a required property of 'system' \
in schema ce30c58b-2863-5d25-ace5-b775337a4e2c"],
          response: response_body.to_json,
          schema_file: 'modules/vaos/app/schemas/appointments.json' }
      )
      Common::SchemaValidator.new(response_body.to_json, 'modules/vaos/app/schemas/appointments.json').validate
    end
  end

  context 'when nested property contains additional properties' do
    it 'logs an error with details' do
      response_body['data'][0]['cancelation_reason']['coding'][0]['foo'] = 'bar'
      expect(Rails.logger).to receive(:error).with(
        'Schema discrepancy found',
        { details:
          ["The property '#/data/0/cancelation_reason/coding/0' contains additional properties [\"foo\"] outside of \
the schema when none are allowed in schema ce30c58b-2863-5d25-ace5-b775337a4e2c"],
          response:
          response_body.to_json,
          schema_file: 'modules/vaos/app/schemas/appointments.json' }
      )
      Common::SchemaValidator.new(response_body.to_json, 'modules/vaos/app/schemas/appointments.json').validate
    end
  end

  context 'when property is of wrong type' do
    it 'logs an error with details' do
      response_body['data'][0]['id'] = 1
      expect(Rails.logger).to receive(:error).with(
        'Schema discrepancy found',
        { details:
          ["The property '#/data/0/id' of type integer did not match the following type: string in schema \
ce30c58b-2863-5d25-ace5-b775337a4e2c"],
          response: response_body.to_json,
          schema_file: 'modules/vaos/app/schemas/appointments.json' }
      )
      Common::SchemaValidator.new(response_body.to_json, 'modules/vaos/app/schemas/appointments.json').validate
    end
  end

  context 'when property violates not null constraint' do
    it 'logs an error with details' do
      response_body['data'][0]['service_type'] = nil
      expect(Rails.logger).to receive(:error).with(
        'Schema discrepancy found',
        { details:
         ["The property '#/data/0/service_type' of type null did not match the following type: string in schema \
ce30c58b-2863-5d25-ace5-b775337a4e2c"],
          response: response_body.to_json,
          schema_file: 'modules/vaos/app/schemas/appointments.json' }
      )
      Common::SchemaValidator.new(response_body.to_json, 'modules/vaos/app/schemas/appointments.json').validate
    end
  end
end
