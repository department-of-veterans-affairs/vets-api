# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Facilities::VaController, type: :controller do
  blank_matcher = lambda { |_r1, _r2|
    true
  }

  it 'should 200' do
    VCR.use_cassette('facilities/va/ppms', match_requests_on: [blank_matcher]) do
      get :ppms, params: { Command: 'Provider', Identifier: '12345' }
      expect(response).to have_http_status(:ok)
    end
  end
end
