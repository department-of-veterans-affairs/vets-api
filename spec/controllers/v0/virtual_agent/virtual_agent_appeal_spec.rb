# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VirtualAgentAppeals', type: :request do
  let(:user) { create(:user, :loa3, ssn: '111223333') }

  describe 'GET /v0/virtual_agent/appeal' do
    it 'returns information when most recent open appeal is compensation' do
      sign_in_as(user)
      # run job
      VCR.use_cassette('caseflow/appeals') do
        get '/v0/virtual_agent/appeal'
        res_body = JSON.parse(response.body)['data']
        expect(response).to have_http_status(:ok)
        expect(res_body).to be_kind_of(Array)
        expect(JSON.parse(response.body)['data'].size).to equal(1)
        expect(res_body[0]).to include({
                                         'appeal_type' => 'Compensation',
                                         'filing_date' => '04/24/2008',
                                         'appeal_status' => 'Please review your Supplemental Statement of the Case'
                                       })
      end
    end

    it 'returns empty array when no appeals are found' do
      sign_in_as(user)

      VCR.use_cassette('caseflow/appeals_empty') do
        get '/v0/virtual_agent/appeal'
        res_body = JSON.parse(response.body)['data']
        expect(response).to have_http_status(:ok)
        expect(res_body).to be_kind_of(Array)
        expect(res_body.size).to equal(0)
      end
    end

    it 'returns most recent claim that is compensation and active' do
      sign_in_as(user)
      VCR.use_cassette('caseflow/virtual_agent_appeals/appeals_old_comp') do
        get '/v0/virtual_agent/appeal'
        res_body = JSON.parse(response.body)['data']
        expect(response).to have_http_status(:ok)
        expect(res_body).to be_kind_of(Array)
        expect(res_body.size).to equal(1)
        expect(res_body[0]).to include({
                                         'appeal_type' => 'Compensation',
                                         'filing_date' => '09/23/2002',
                                         'appeal_status' => 'Your appeal was closed'
                                       })
      end
    end

    it 'returns an empty array when no active compensation appeals are found' do
      sign_in_as(user)

      VCR.use_cassette('caseflow/virtual_agent_appeals/appeals_inactive_comp') do
        get '/v0/virtual_agent/appeal'

        res_body = JSON.parse(response.body)['data']
        expect(response).to have_http_status(:ok)
        expect(res_body).to be_kind_of(Array)
        expect(res_body.size).to equal(0)
      end
    end

    it 'returns an empty array when no active appeals are found' do
      sign_in_as(user)

      VCR.use_cassette('caseflow/virtual_agent_appeals/appeals_inactive') do
        get '/v0/virtual_agent/appeal'
        res_body = JSON.parse(response.body)['data']
        expect(response).to have_http_status(:ok)
        expect(res_body).to be_kind_of(Array)
        expect(res_body.size).to equal(0)
      end
    end

    it 'returns correct appeal status message for field grant appeal status type' do
      sign_in_as(user)

      VCR.use_cassette('caseflow/virtual_agent_appeals/appeals_field_grant_status_type') do
        get '/v0/virtual_agent/appeal'
        res_body = JSON.parse(response.body)['data']
        expect(response).to have_http_status(:ok)
        expect(res_body).to be_kind_of(Array)
        expect(res_body.size).to equal(1)
        expect(res_body[0]).to include({
                                         'appeal_type' => 'Compensation',
                                         'filing_date' => '04/24/2008',
                                         'appeal_status' => 'The Veterans Benefits Administration granted your appeal'
                                       })
      end
    end

    it 'returns correct filing date when event dates are unsorted' do
      sign_in_as(user)

      VCR.use_cassette('caseflow/virtual_agent_appeals/appeals_unsorted_event_dates') do
        get '/v0/virtual_agent/appeal'
        res_body = JSON.parse(response.body)['data']
        expect(response).to have_http_status(:ok)
        expect(res_body).to be_kind_of(Array)
        expect(res_body.size).to equal(1)
        expect(res_body[0]).to include({
                                         'appeal_type' => 'Compensation',
                                         'filing_date' => '09/23/2002',
                                         'appeal_status' => 'Your appeal was closed'
                                       })
      end
    end
  end
end
