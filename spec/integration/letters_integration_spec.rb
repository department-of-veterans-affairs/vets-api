# frozen_string_literal: true
require 'rails_helper'

describe 'letters integration test', type: :request, integration: true do
  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3, :j_wood) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  it 'should return the letters for test account Jaime Wood' do
    get '/v0/letters', nil, auth_header
    expect(response).to have_http_status(:ok)
    expect(response.body).to include_json(
      data: {
        id: '',
        type: 'evss_letters_letters_responses',
        attributes: {
          letters: [
            {
              name: 'Proof of Service Letter',
              letter_type: 'proof_of_service'
            },
            {
              name: 'Service Verification Letter',
              letter_type: 'service_verification'
            },
            {
              name: 'Civil Service Preference Letter',
              letter_type: 'civil_service'
            },
            {
              name: 'Benefit Summary Letter',
              letter_type: 'benefit_summary'
            },
            {
              name: 'Benefit Verification Letter',
              letter_type: 'benefit_verification'
            }
          ],
          full_name: 'Jamie J Wood Iii'
        }
      }
    )
  end
end
