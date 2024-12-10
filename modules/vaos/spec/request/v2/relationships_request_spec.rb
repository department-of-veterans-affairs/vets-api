# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'relationships', :skip_mvi, type: :request do
  before do
    sign_in_as(current_user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
    allow(Flipper).to receive(:enabled?).and_return(true)
  end

  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  context 'loa3 user' do
    let(:current_user) { build(:user, :vaos) }

    describe 'GET relationships' do
      let(:params) { { clinical_service_id: 'primaryCare', facility_id: '100' } }

      context 'patient relationships' do
        it 'successfully returns patient relationships' do
          VCR.use_cassette('vaos/v2/relationships/get_relationships',
                           match_requests_on: %i[method path query]) do
            get '/vaos/v2/relationships?clinicalServiceId=primaryCare&facilityId=100', params:,
                                                                                       headers: inflection_header
            expect(response).to have_http_status(:ok)

            relationships = JSON.parse(response.body)['data']
            expect(relationships).not_to be_nil
            expect(relationships.length).to eq(4)
            relationships.each do |relationship|
              expect(relationship['type']).to eq('relationship')
            end
          end
        end
      end
    end
  end
end
