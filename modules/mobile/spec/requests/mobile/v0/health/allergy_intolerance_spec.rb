# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'
require 'unique_user_events'

RSpec.describe 'Mobile::V0::Health::AllergyIntolerances', type: :request do
  let!(:user) { sis_user(icn: '32000225') }

  let(:allergy_intolerance_response) do
    [{ 'id' => 'I2-FY4N5GUAQ4IZQVQZUPDFN43S4A000000',
       'type' => 'allergy_intolerance',
       'attributes' =>
         { 'resourceType' => 'AllergyIntolerance',
           'type' => 'allergy',
           'clinicalStatus' => {
             'coding' => [
               { 'system' => 'http://hl7.org/fhir/ValueSet/allergyintolerance-clinical',
                 'code' => 'active' }
             ]
           },
           'category' => ['environment'],
           'code' => {
             'coding' => [
               {
                 'system' => 'http://snomed.info/sct',
                 'code' => '300916003',
                 'display' => 'Latex allergy'
               }
             ],
             'text' => 'Latex allergy'
           },
           'recordedDate' => '1999-01-07T01:43:31Z',
           'patient' => {
             'reference' => 'https://sandbox-api.va.gov/services/fhir/v0/r4/Patient/43000199',
             'display' => 'Ms. Carlita746 Kautzer186'
           },
           'notes' => [{
             'authorReference' => {
               'reference' => 'https://sandbox-api.va.gov/services/fhir/v0/r4/Practitioner/I2-HRJI2MVST2IQSPR7U5SACWIWZA000000',
               'display' => 'DR. JANE460 DOE922 MD'
             },
             'time' => '1999-01-07T01:43:31Z',
             'text' => 'Latex allergy'
           }],
           'recorder' => {
             'reference' => 'https://sandbox-api.va.gov/services/fhir/v0/r4/Practitioner/I2-4ZXYC2SQAZCHMOWPPFNLOY65GE000000',
             'display' => 'DR. THOMAS359 REYNOLDS206 PHD'
           },
           'reactions' => [{
             'substance' => {
               'coding' => [
                 {
                   'system' => 'http://snomed.info/sct',
                   'code' => '300916003',
                   'display' => 'Latex allergy'
                 }
               ],
               'text' => 'Latex allergy'
             },
             'manifestation' => [
               {
                 'coding' => [
                   {
                     'system' => 'urn:oid:2.16.840.1.113883.6.233',
                     'code' => '43000006',
                     'display' => 'Itchy Watery Eyes'
                   }
                 ],
                 'text' => 'Itchy Watery Eyes'
               }
             ]
           }] } }]
  end

  let(:allergy_intolerance_response_empty_fields) do
    [{ 'id' => 'I2-FY4N5GUAQ4IZQVQZUPDFN43S4A000000',
       'type' => 'allergy_intolerance',
       'attributes' =>
         { 'resourceType' => 'AllergyIntolerance',
           'type' => 'allergy',
           'clinicalStatus' => { 'coding' => [] },
           'category' => ['environment'],
           'code' => {
             'coding' => [
               {
                 'system' => 'http://snomed.info/sct',
                 'code' => '300916003',
                 'display' => 'Latex allergy'
               }
             ],
             'text' => 'Latex allergy'
           },
           'recordedDate' => nil,
           'patient' => {
             'reference' => nil,
             'display' => nil
           },
           'notes' => [],
           'recorder' => {
             'reference' => nil,
             'display' => nil
           },
           'reactions' => [] } }]
  end

  context 'when legacy is used' do
    before { Flipper.disable(:mobile_allergy_intolerance_model) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

    it 'responds to GET #index' do
      VCR.use_cassette('rrd/lighthouse_allergy_intolerances') do
        get '/mobile/v0/health/allergy-intolerances', headers: sis_headers
      end

      expect(response).to be_successful
      expect(response.parsed_body['data']).to eq(allergy_intolerance_response)

      body = JSON.parse(response.body)

      expect(body['data']).to be_an(Array)
      expect(body['data'].size).to be 1

      item = body['data'][0]
      expect(item['type']).to eq('allergy_intolerance')
      expect(item['attributes']['category'][0]).to eq('environment')
    end

    it 'handles empty fields gracefully' do
      VCR.use_cassette('rrd/lighthouse_allergy_intolerances_empty_fields') do
        get '/mobile/v0/health/allergy-intolerances', headers: sis_headers
      end

      expect(response).to be_successful
      expect(response.parsed_body['data']).to eq(allergy_intolerance_response_empty_fields)

      body = JSON.parse(response.body)

      expect(body['data']).to be_an(Array)
      expect(body['data'].size).to be 1

      item = body['data'][0]
      expect(item['type']).to eq('allergy_intolerance')
      expect(item['attributes']['category'][0]).to eq('environment')
    end
  end

  context 'when non-legacy is used' do
    before { Flipper.enable_actor(:mobile_allergy_intolerance_model, user) } # rubocop:disable Project/ForbidFlipperToggleInSpecs
    after { Flipper.disable(:mobile_allergy_intolerance_model) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

    it 'responds to GET #index' do
      allow(UniqueUserEvents).to receive(:log_events)
      VCR.use_cassette('rrd/lighthouse_allergy_intolerances') do
        get '/mobile/v0/health/allergy-intolerances', headers: sis_headers
      end

      expect(response).to be_successful
      expect(response.parsed_body['data']).to eq(allergy_intolerance_response)
      body = JSON.parse(response.body)

      expect(body['data']).to be_an(Array)
      expect(body['data'].size).to be 1

      item = body['data'][0]
      expect(item['type']).to eq('allergy_intolerance')
      expect(item['attributes']['category'][0]).to eq('environment')

      # Verify event logging was called
      expect(UniqueUserEvents).to have_received(:log_events).with(
        user: anything,
        event_names: [
          UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ACCESSED,
          UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ALLERGIES_ACCESSED
        ]
      )
    end
  end
end
