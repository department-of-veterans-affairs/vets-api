# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VRE::V0::Ch31CaseMilestones', type: :request do
  include SchemaMatchers

  before { sign_in_as(user) }

  describe 'POST vre/v0/ch31_case_milestones' do
    let(:valid_request_body) do
      {
        milestones: [
          {
            milestoneType: 'ORIENTATION_COMPLETION',
            isMilestoneCompleted: true,
            milestoneCompletionDate: '2025-01-15',
            milestoneSubmissionUser: 'john.smith'
          }
        ]
      }
    end

    context 'when milestones update successfully' do
      let(:user) { create(:user, icn: '1008711076V809443') }

      it 'returns 200 response' do
        VCR.use_cassette('vre/ch31_case_milestones/200') do
          post '/vre/v0/ch31_case_milestones', params: valid_request_body
          expect(response).to match_response_schema('vre/ch31_case_milestones')
          assert_response :success
        end
      end
    end

    context 'when no icn present' do
      let(:user) { create(:user, icn: nil) }

      it 'returns 403 response' do
        post '/vre/v0/ch31_case_milestones', params: valid_request_body
        expect(response).to have_http_status(:forbidden)
        message = JSON.parse(response.body)['errors'].first['detail']
        expect(message).to eq('ICN is required')
      end
    end

    context 'when no milestone sent' do
      let(:user) { create(:user, icn: '1008711076V809443') }

      it 'returns 403 response' do
        VCR.use_cassette('vre/ch31_case_milestones/403_no_milestone') do
          post '/vre/v0/ch31_case_milestones', params: { milestones: [] }
          expect(response).to have_http_status(:forbidden)
          message = JSON.parse(response.body)['errors'].first['detail']
          expect(message).to eq('At least one milestone is required')
        end
      end
    end

    context 'when no application for ICN' do
      let(:user) { create(:user, icn: '1008711076V809443') }

      it 'returns 403 response' do
        VCR.use_cassette('vre/ch31_case_milestones/403_no_application') do
          post '/vre/v0/ch31_case_milestones', params: valid_request_body
          expect(response).to have_http_status(:forbidden)
          message = JSON.parse(response.body)['errors'].first['detail']
          expect(message).to eq('RES does not have an application associated to this ICN')
        end
      end
    end

    context 'when upstream service is not available' do
      let(:user) { create(:user, icn: '1008711076V809443') }

      it 'returns 503 response' do
        VCR.use_cassette('vre/ch31_case_milestones/500') do
          post '/vre/v0/ch31_case_milestones', params: valid_request_body
          expect(response).to have_http_status(:service_unavailable)
          message = JSON.parse(response.body)['errors'].first['detail']
          expect(message).to eq('Service Unavailable')
        end
      end
    end
  end
end
