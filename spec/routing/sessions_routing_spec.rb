# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'routes for Session', type: :routing do
  V0::SessionsController::REDIRECT_URLS.each do |type|
    it "routes /sessions/#{type}/new to SessionsController#new with type: #{type}" do
      expect(get("/sessions/#{type}/new")).to route_to(
        controller: 'v0/sessions',
        action: 'new',
        type: type
      )
    end
  end

  it 'doesnt route something not matching the constraint' do
    expect(get('/sessions/unknown/new')).to route_to(
      controller: 'application',
      action: 'routing_error',
      path: 'sessions/unknown/new'
    )
  end
end
