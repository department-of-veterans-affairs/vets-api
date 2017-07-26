# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Preneeds Burial Form Integration', type: :request do
  include SchemaMatchers

  let(:params) do
    { pre_need_request: JSON.parse(build(:burial_form).to_json, symbolize_names: true) }
  end

  context 'with valid input' do
    it 'responds to POST #create' do
      VCR.use_cassette('preneeds/burial_forms/creates_a_pre_need_burial_form') do
        post '/v0/preneeds/burial_forms', params
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('preneeds/receive_applications')
    end
  end

  context 'with invalid input' do
    it 'returns an with error' do
      params[:pre_need_request][:veteran].delete(:military_status)
      post '/v0/preneeds/burial_forms', params

      error = JSON.parse(response.body)['errors'].first

      expect(error['status']).to eq('422')
      expect(error['title']).to match(/validation error/i)
      expect(error['detail']).to match(/militaryStatus/)
    end
  end

  context 'with a failed burial form submittal from EOAS' do
    it 'returns with a VA900 error when status is 500' do
      VCR.use_cassette('preneeds/burial_forms/burial_form_with_invalid_applicant_address2') do
        params[:pre_need_request][:applicant][:mailing_address][:address2] = '1' * 21
        post '/v0/preneeds/burial_forms', params
      end

      error = JSON.parse(response.body)['errors'].first

      expect(error['status']).to eq('400')
      expect(error['title']).to match(/operation failed/i)
      expect(error['detail']).to match(/Error committing transaction/i)
    end

    it 'returns with a VA900 error when the status is 200' do
      VCR.use_cassette('preneeds/burial_forms/burial_form_with_duplicate_tracking_number') do
        allow_any_instance_of(Preneeds::BurialForm).to receive(:generate_tracking_number).and_return('19')
        post '/v0/preneeds/burial_forms', params
      end

      error = JSON.parse(response.body)['errors'].first

      expect(error['status']).to eq('400')
      expect(error['title']).to match(/operation failed/i)
      expect(error['detail']).to match(/Tracking number '19' already exists/i)
    end
  end
end
