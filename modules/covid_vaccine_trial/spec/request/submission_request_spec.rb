# frozen_string_literal: true

require 'rails_helper'
require_relative '../covid_vaccine_trial_spec_helper.rb'

RSpec.configure do |c|
  c.include CovidVaccineTrialSpecHelper
end

RSpec.describe 'covid vaccine trial screener submissions', type: :request do
  describe 'POST /covid-vaccine/screener/create' do
    let(:valid)   { read_fixture('valid-submission.json') }
    let(:invalid) { read_fixture('no-name-submission.json') }

    it 'validates the payload' do
      expect_any_instance_of(CovidVaccineTrial::Screener::FormService).to receive(:valid_submission?)

      post '/covid-vaccine/screener/create', params: valid
    end

    context 'with a valid payload' do
      it 'returns a 202' do
        post '/covid-vaccine/screener/create', params: valid

        expect(response).to have_http_status(:accepted)
      end
    end

    context 'with an invalid payload' do
      it 'returns a description of the errors' do
        post '/covid-vaccine/screener/create', params: invalid

        expect(response).to have_http_status(422)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq({'missing_keys' => ["fullName"]})
      end
    end
  end
end