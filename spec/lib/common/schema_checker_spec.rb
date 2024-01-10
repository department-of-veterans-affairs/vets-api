# frozen_string_literal: true

require 'rails_helper'
require 'common/schema_checker'

describe Common::SchemaChecker do
  let(:response_object) do
    lambda do |body, success_status|
      OpenStruct.new(
        response_body: body,
        success?: success_status
      )
    end
  end

  let(:valid_response_body) do
    { data: [{ id: '121133',
               identifier: [{ system: 'http://med.va.gov/fhir/urn/vaos/vista/983/appointment/id',
                              value: '999;20220827.094500' }],
               kind: 'clinic',
               status: 'cancelled',
               service_type: 'optometry',
               patient_icn: '1012846043V576341',
               location_id: '983',
               clinic: '455',
               start: '2022-08-27T10:30:00Z',
               cancelation_reason: { coding: [{ system: 'http://terminology.hl7.org/CodeSystem/appointment-cancellation-reason',
                                                code: 'pat',
                                                display: 'The appointment was cancelled by the patient' }] },
               cancellable: false,
               extension: { cc_location: { address: {} }, vista_status: ['CANCELLED BY PATIENT', 'FUTURE'] } }] }
  end

  context 'when response matches schema' do
    it 'does not log an error' do
      expect(Rails.logger).not_to receive(:error)
      response = response_object.call(valid_response_body, true)
      Common::SchemaChecker.new(response, 'modules/vaos/app/schemas/appointments.json').validate
    end
  end

  context 'when response has additional attributes' do
    it 'logs an error with details' do
      expect(Rails.logger).to receive(:error)
      body = valid_response_body[:data].first.merge(foo: 'bar')
      response = response_object.call(body, true)
      Common::SchemaChecker.new(response, 'modules/vaos/app/schemas/appointments.json').validate
    end
  end

  context 'when response is missing required attributes' do
    it 'logs an error with details' do
      expect(Rails.logger).to receive(:error)
      body = valid_response_body[:data].first.except(:id)
      response = response_object.call(body, true)
      Common::SchemaChecker.new(response, 'modules/vaos/app/schemas/appointments.json').validate
    end
  end

  context 'when request was unsuccessful' do
    it 'does not check the schema' do
      expect(Rails.logger).not_to receive(:error)
      expect(JSON::Validator).not_to receive(:fully_validate)
      response = response_object.call(valid_response_body, false)
      Common::SchemaChecker.new(response, 'modules/vaos/app/schemas/appointments.json').validate
    end
  end
end
