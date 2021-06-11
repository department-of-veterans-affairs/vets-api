# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Test User Dashboard', type: :request do
  context 'index' do
    context 'without any authentication headers' do
      get '/test_user_dashboard/tud_accounts'

      it { expect(response.status).to eq 403 }
      it { expect(response.content_type).to eq 'text/html' }
    end

    context 'with authentication headers' do
      get '/test_user_dashboard/tud_accounts', '', { 'PK' => 'application/json' }

      it { expect(response.status).to eq 200 }
      it { expect(response.content_type).to eq 'application/json; charset=utf-8' }
    end
  end
end
