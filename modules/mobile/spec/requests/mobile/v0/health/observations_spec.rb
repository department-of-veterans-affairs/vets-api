# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::Health::Observations', type: :request do
  let!(:user) { sis_user(icn: '32000225') }

  let(:observation_response) do
    {
      'id' => 'I2-ILWORI4YUOUAR5H2GCH6ATEFRM000000',
      'type' => 'observation',
      'attributes' => {
        'status' => 'final',
        'category' => [
          {
            'coding' => [
              {
                'system' => 'http://terminology.hl7.org/CodeSystem/observation-category',
                'code' => 'laboratory',
                'display' => 'Laboratory'
              }
            ],
            'text' => 'Laboratory'
          }
        ],
        'code' => {
          'coding' => [
            {
              'system' => 'http://loinc.org',
              'code' => '2339-0',
              'display' => 'Glucose'
            }
          ],
          'text' => 'Glucose'
        },
        'subject' => {
          'reference' => 'https://sandbox-api.va.gov/services/fhir/v0/r4/Patient/1000005',
          'display' => 'Mr. Shane235 Bartell116'
        },
        'effectiveDateTime' => '1998-03-16T05:56:37Z',
        'issued' => '1998-03-16T05:56:37Z',
        'performer' => [
          {
            'reference' => 'https://sandbox-api.va.gov/services/fhir/v0/r4/Practitioner/I2-4ZXYC2SQAZCHMOWPPFNLOY65GE000000',
            'display' => 'DR. THOMAS359 REYNOLDS206 PHD'
          }
        ],
        'valueQuantity' => {
          'value' => 78.278855002875,
          'unit' => 'mg/dL',
          'system' => 'http://unitsofmeasure.org',
          'code' => 'mg/dL'
        }
      }
    }
  end

  it 'responds to GET #show' do
    VCR.use_cassette('mobile/lighthouse_disability_rating/introspect_active') do
      VCR.use_cassette('rrd/lighthouse_observation') do
        get '/mobile/v0/health/observations/I2-ILWORI4YUOUAR5H2GCH6ATEFRM000000', headers: sis_headers
      end
    end
    expect(PersonalInformationLog.count).to eq(0)
    expect(response).to be_successful
    expect(response.parsed_body['data']).to eq(observation_response)
  end
end
