# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'routes for Profile', type: :routing do
  it 'creates an alias route to the v0/addresses#show RESTful route' do
    expect(get('/v0/profile/mailing_address')).to route_to(
      'format' => 'json',
      'controller' => 'v0/addresses',
      'action' => 'show'
    )
  end
end
