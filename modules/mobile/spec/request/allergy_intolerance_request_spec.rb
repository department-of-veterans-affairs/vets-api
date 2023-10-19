# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/sis_session_helper'

RSpec.describe 'allergy intolerances', type: :request do
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

  it 'responds to GET #index' do
    VCR.use_cassette('mobile/lighthouse_disability_rating/introspect_active') do
      VCR.use_cassette('rrd/lighthouse_allergy_intolerances') do
        get '/mobile/v0/health/allergy-intolerances', headers: sis_headers
      end
    end

    expect(response).to be_successful
    expect(response.parsed_body['data']).to eq(allergy_intolerance_response)
  end
end
