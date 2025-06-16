# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::DatadogActionController, type: :controller do
  describe 'POST #create' do
    let(:allowed_metric) { 'labs_and_tests_list' }
    let(:disallowed_metric) { 'not_in_allowlist' }

    before do
      # make sure the allowlist is predictable
      stub_const('DatadogMetrics::ALLOWLIST', [allowed_metric])
    end

    context 'when metric is allowed' do
      it 'increments the metric with supplied tags and returns 204' do
        tags = %w[tag1 tag2]
        expect(StatsD).to receive(:increment)
          .with("frontend.#{allowed_metric}", tags:)

        post :create, params: { metric: allowed_metric, tags: }

        expect(response).to have_http_status(:no_content)
        expect(response.body).to be_blank
      end

      it 'uses an empty tags array when none are provided' do
        expect(StatsD).to receive(:increment)
          .with("frontend.#{allowed_metric}", tags: [])

        post :create, params: { metric: allowed_metric }

        expect(response).to have_http_status(:no_content)
        expect(response.body).to be_blank
      end
    end

    context 'when metric is not allowed' do
      it 'does not increment and returns 400 with an error message' do
        expect(StatsD).not_to receive(:increment)

        post :create, params: { metric: disallowed_metric }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to eq('error' => 'Metric not allowed')
      end
    end
  end
end
