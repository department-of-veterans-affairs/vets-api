# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TestUserDashboard::TudAccountsController, type: :request do
  before do
    # Copied from https://github.com/department-of-veterans-affairs/va.gov-workstreams/blob/master/spec/requests/workstreams_spec.rb
    # Use RSpec mocks to avoid pinging live APIs during tests
    allow_any_instance_of(described_class).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(described_class).to receive(:authorized?).and_return(true)
  end

  describe '#index' do
    it 'renders a successful response' do
      get('/test_user_dashboard/tud_accounts')

      expect(response).to have_http_status(:ok)
    end
  end

  describe '#update' do
    let(:tud_account) { create(:tud_account, id: '123') }
    let(:notes) { 'Test note string goes here.' }

    it 'updates the tud account notes field' do
      allow(TestUserDashboard::TudAccount).to receive(:find).and_return(tud_account)
      put('/test_user_dashboard/tud_accounts/123', params: { notes: notes })

      expect(response).to have_http_status(:ok)
      expect(tud_account.notes).to eq('Test note string goes here.')
    end
  end
end
