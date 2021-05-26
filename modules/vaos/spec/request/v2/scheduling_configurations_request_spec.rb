# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'vaos scheduling/configurations', type: :request, skip_mvi: true do
  include SchemaMatchers

  before do
    sign_in_as(current_user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  context 'vaos user' do
    let(:current_user) { build(:user, :vaos) }

    describe 'GET scheduling/configurations' do
      let(:facility_ids) { 489 }
      let(:cc_enabled) { false }
      let(:params) { { facility_ids: facility_ids, cc_enabled: cc_enabled } }

      context 'returns a set of configurations' do
        it 'has access and returns configurations' do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_200',
                           match_requests_on: %i[method uri]) do
            get '/vaos/v2/scheduling/configurations', params: { facility_ids: %w[489], cc_enabled: false }

            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data'].size).to eq(1)
            expect(response).to match_response_schema('vaos/v2/scheduling_configurations', { strict: false })
          end
        end
      end
    end
  end
end
