# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VRE::V0::Ch31EligibilityStatus', type: :request do
  include SchemaMatchers

  describe 'GET vre/v0/ch31_eligibility_status' do
    context 'when eligibility status available' do

    let(:user) { create(:user, icn: '1012667145V762142') }

    before { sign_in_as(user)}

      it 'returns 200 response' do
        VCR.use_cassette('vre/ch31_eligibility/200') do
          get '/vre/v0/ch31_eligibility_status'
          byebug
        end
      end
    end
  end
end