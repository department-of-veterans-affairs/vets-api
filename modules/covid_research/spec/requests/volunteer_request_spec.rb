# frozen_string_literal: true

require 'rails_helper'
require_relative '../covid_research_spec_helper.rb'

RSpec.configure do |c|
  c.include CovidResearchSpecHelper
end

RSpec.describe 'covid research volunteer submissions', type: :request do
  describe 'POST /covid-research/volunteer/create' do
    let(:valid)   { read_fixture('valid-submission.json') }
    let(:invalid) { read_fixture('no-name-submission.json') }

    it 'validates the payload' do
      expect_any_instance_of(CovidResearch::Volunteer::FormService).to receive(:valid?)

      post '/covid-research/volunteer/create', params: valid
    end

    context 'metrics' do
      it 'records a metric for each call' do
        expect { post '/covid-research/volunteer/create', params: valid }.to trigger_statsd_increment(
          'api.covid_research.volunteer.create.total', times: 1, value: 1
        )
      end

      it 'records a metric on failure' do
        expect { post '/covid-research/volunteer/create', params: invalid }.to trigger_statsd_increment(
          'api.covid_research.volunteer.create.fail', times: 1, value: 1
        )
      end
    end

    context 'with a valid payload' do
      it 'returns a 202' do
        post '/covid-research/volunteer/create', params: valid

        expect(response).to have_http_status(:accepted)
      end
    end

    context 'with an invalid payload' do
      it 'returns a description of the errors' do
        post '/covid-research/volunteer/create', params: valid

        expect(JSON.parse(response.body)).to have_key('errors')
      end

      it 'returns a 422 status' do
        post '/covid-research/volunteer/create', params: invalid

        expect(response).to have_http_status(422)
      end
    end
  end
end