# frozen_string_literal: true

require 'rails_helper'

describe 'Preferences', type: :request do
  include SchemaMatchers
  include RequestHelper

  context 'with a loa1 user' do
    include_context 'login_as_loa1'
    let(:preference) { create(:preference) }

    before(:each) do
      login_as_loa1
    end

    it 'returns a preference' do
      get '/v0/preferences', code: preference.code, 'Authorization' => "Token token=#{session.token}"
      expect(response).to have_http_status(:ok)
    end
  end
end
