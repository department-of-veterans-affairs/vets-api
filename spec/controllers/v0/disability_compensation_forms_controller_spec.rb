# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::DisabilityCompensationFormsController, type: :controller do
  let(:user) { build(:user, :loa3) }

  before do
    sign_in_as(user)
  end

  describe '#separation_locations' do
    it 'returns separation locations' do
      VCR.use_cassette('evss/reference_data/get_intake_sites') do
        get(:separation_locations)
        expect(JSON.parse(response.body)['separation_locations'].present?).to eq(true)
      end
    end

    it 'will use the cached response on the second request' do
      VCR.use_cassette('evss/reference_data/get_intake_sites') do
        2.times do
          get(:separation_locations)
          expect(response.status).to eq(200)
        end
      end
    end
  end
end
