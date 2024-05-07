# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin API', type: :request do
  it 'Provides a status page with status OK and git SHA' do
    get '/v0/status'
    assert_response :success

    json = JSON.parse(response.body)
    git_rev = AppInfo::GIT_REVISION
    pg_up = AppInfo.postgres_up

    expect(response.headers['X-Git-SHA']).to eq(git_rev)
    expect(json['git_revision']).to eq(git_rev)
    expect(json['postgres_up']).to eq(pg_up)
  end
end
