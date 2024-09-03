# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::Health::LabsAndTests', type: :request do
  let!(:user) { sis_user(icn: '32000225') }

  let(:diagnostic_report_response) do
    [
      { 'id' => 'I2-EWSRFHMJRWT3KNBUB542ZJYEKM000000',
        'type' => 'diagnostic_report',
        'attributes' =>
          { 'category' => 'Laboratory',
            'code' => 'panel',
            'subject' => {
              'reference' => 'https://sandbox-api.va.gov/services/fhir/v0/r4/Patient/1000005',
              'display' => 'Mr. Shane235 Bartell116'
            },
            'effectiveDateTime' => '1998-03-16T05:56:37Z',
            'issued' => '1998-03-16T05:56:37Z',
            'result' => [
              {
                'reference' => 'http://www.example.com/mobile/v0/health/observations/I2-ILWORI4YUOUAR5H2GCH6ATEFRM000000',
                'display' => 'Glucose'
              },
              {
                'reference' => 'http://www.example.com/mobile/v0/health/observations/I2-6DTSU5DDGS3NBDOKN4BOZDISGE000000',
                'display' => 'Urea Nitrogen'
              },
              {
                'reference' => 'http://www.example.com/mobile/v0/health/observations/I2-4OWFD25REFR6P362ZJ2PY3ACWU000000',
                'display' => 'Creatinine'
              },
              {
                'reference' => 'http://www.example.com/mobile/v0/health/observations/I2-35GNQKPTBRNMPBTUGEF4F62HNI000000',
                'display' => 'Calcium'
              },
              {
                'reference' => 'http://www.example.com/mobile/v0/health/observations/I2-OOVHBIQFYCOORXPBB74H42FPJU000000',
                'display' => 'Sodium'
              },
              {
                'reference' => 'http://www.example.com/mobile/v0/health/observations/I2-C3P7YCD3DCX7KNRRR5DOKLDCGA000000',
                'display' => 'Potassium'
              },
              { 'reference' => 'http://www.example.com/mobile/v0/health/observations/I2-K4NGUOCHCS3ULYOFMDN5ZRJW6U000000',
                'display' => 'Chloride' },
              {
                'reference' => 'http://www.example.com/mobile/v0/health/observations/I2-D5TBNWZQSFRRBOBSBCC7QQRPQY000000',
                'display' => 'Carbon Dioxide'
              }
            ] } }
    ]
  end

  it 'responds to GET #index' do
    VCR.use_cassette('mobile/lighthouse_disability_rating/introspect_active') do
      VCR.use_cassette('rrd/lighthouse_diagnostic_reports') do
        get '/mobile/v0/health/labs-and-tests', headers: sis_headers
      end
    end

    expect(response).to be_successful
    expect(response.parsed_body['data']).to eq(diagnostic_report_response)
  end
end
