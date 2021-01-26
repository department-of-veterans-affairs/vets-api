# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Test User Dashboard', type: :request do
  context 'index' do
    context 'with json' do
      before { get '/test_user_dashboard/tud_accounts' }

      it { expect(response.status).to eq 200 }
      it { expect(response.content_type).to eq 'application/json; charset=utf-8' }
    end
  end
end
