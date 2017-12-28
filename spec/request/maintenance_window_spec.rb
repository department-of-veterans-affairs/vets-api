# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Maintenance Window API', type: :request do
  it 'Provides a list of upcoming maintenance windows' do
    get '/v0/maintenance_windows'
    assert_response :success
  end
end
