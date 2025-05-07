# frozen_string_literal: true

require 'rails_helper'
require 'bb/client' # required to stub responses

RSpec.describe 'V0::HealthRecords', type: :request do
  include SchemaMatchers

  let(:authenticated_client) do
    BB::Client.new(session: { user_id: 123, expires_at: Time.current + (60 * 60), token: })
  end
  let(:token) { 'GkuX2OZ4dCE=48xrH6ObGXZ45ZAg70LBahi7CjswZe8SZGKMUVFIU88=' }
  let(:current_user) { build(:user, :mhv, va_patient: false, mhv_account_type: 'Basic') }
  let(:params) do
    {
      from_date: 10.years.ago.iso8601,
      to_date: Time.now.iso8601,
      data_classes: BB::GenerateReportRequestForm::ELIGIBLE_DATA_CLASSES
    }
  end
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  before do
    allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(false)
    allow(BB::Client).to receive(:new).and_return(authenticated_client)
    sign_in_as(current_user)
  end

  context 'forbidden user' do
    let(:current_user) { build(:user) }

    it 'raises access denied' do
      get '/v0/health_records/refresh'

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['errors'].first['detail'])
        .to eq('You do not have access to health records')
    end
  end

  it 'responds to GET #refresh' do
    VCR.use_cassette('bb_client/gets_a_list_of_extract_statuses') do
      get '/v0/health_records/refresh'
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('extract_statuses')
  end

  it 'responds to GET #refresh when camel-inflected' do
    VCR.use_cassette('bb_client/gets_a_list_of_extract_statuses') do
      get '/v0/health_records/refresh', headers: inflection_header
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_camelized_response_schema('extract_statuses')
  end

  it 'responds to GET #eligible_data_classes' do
    VCR.use_cassette('bb_client/gets_a_list_of_eligible_data_classes') do
      get '/v0/health_records/eligible_data_classes'
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('eligible_data_classes')
  end

  it 'responds to GET #eligible_data_classes when camel-inflected' do
    VCR.use_cassette('bb_client/gets_a_list_of_eligible_data_classes') do
      get '/v0/health_records/eligible_data_classes', headers: inflection_header
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_camelized_response_schema('eligible_data_classes')
  end

  it 'responds to POST #create to generate a new report' do
    VCR.use_cassette('bb_client/generates_a_report') do
      post '/v0/health_records', params:
    end

    expect(response).to be_accepted
    expect(response.body).to be_a(String)
    expect(response.body).to be_empty
  end

  it 'responds to GET #show to fetch the created report' do
    VCR.use_cassette('bb_client/gets_a_pdf_version_of_a_report') do
      get '/v0/health_records'
    end

    expect(response).to be_successful
    expect(response.headers['Content-Disposition'])
      .to eq('inline; filename=mhv_GPTESTKFIVE_20161229_0057.pdf')
    expect(response.headers['Content-Type']).to eq('application/pdf')
    expect(response.body).to be_a(String)
  end

  it 'responds to GET #show with txt to fetch the txt version of created report' do
    VCR.use_cassette('bb_client/gets_a_text_version_of_a_report') do
      get '/v0/health_records', params: { doc_type: 'txt' }
    end

    expect(response).to be_successful
    expect(response.headers['Content-Disposition'])
      .to eq('inline; filename=mhv_GPTESTKFIVE_20170130_1901.txt')
    expect(response.headers['Content-Type']).to eq('text/plain')
    expect(response.body).to be_a(String)
  end

  it 'handles an error response for a report request' do
    VCR.use_cassette('bb_client/report_error_response') do
      get '/v0/health_records', params: { doc_type: 'txt' }
    end

    expect(response).to have_http_status(:service_unavailable)
  end
end
