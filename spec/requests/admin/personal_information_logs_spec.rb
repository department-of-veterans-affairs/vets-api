# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::PersonalInformationLogs', type: :request do
  # In test environment, GitHub auth is disabled by default (github_oauth_key is nil)
  # These tests verify behavior without authentication enabled

  describe 'GET /admin/personal_information_logs' do
    let!(:log1) do
      PersonalInformationLog.create!(
        error_class: 'HealthCareApplication ValidationError',
        data: { test: 'data1' },
        created_at: 1.day.ago
      )
    end
    let!(:log2) do
      PersonalInformationLog.create!(
        error_class: 'HealthCareApplication FailedWontRetry',
        data: { test: 'data2' },
        created_at: 2.days.ago
      )
    end

    it 'returns success' do
      get '/admin/personal_information_logs'
      expect(response).to have_http_status(:ok)
    end

    it 'filters by error_class' do
      get '/admin/personal_information_logs', params: { error_class: 'HealthCareApplication ValidationError' }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('HealthCareApplication ValidationError')
    end

    it 'filters by date range' do
      get '/admin/personal_information_logs',
          params: { from_date: 3.days.ago.to_date, to_date: 1.day.ago.to_date }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /admin/personal_information_logs/:id' do
    let!(:log) do
      PersonalInformationLog.create!(
        error_class: 'TestError',
        data: { test: 'data' }
      )
    end

    it 'returns success' do
      get "/admin/personal_information_logs/#{log.id}"
      expect(response).to have_http_status(:ok)
    end

    it 'displays log details' do
      get "/admin/personal_information_logs/#{log.id}"
      expect(response.body).to include('TestError')
      expect(response.body).to include(log.id.to_s)
    end
  end

  describe 'GET /admin/personal_information_logs/export' do
    let!(:log) do
      PersonalInformationLog.create!(
        error_class: 'TestError',
        data: { test: 'data' }
      )
    end

    it 'returns csv file' do
      get '/admin/personal_information_logs/export'
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('text/csv')
      expect(response.headers['Content-Disposition']).to include('attachment')
    end

    it 'includes log data in csv' do
      get '/admin/personal_information_logs/export'
      csv_data = response.body
      expect(csv_data).to include('TestError')
      expect(csv_data).to include(log.id.to_s)
    end

    it 'respects filters in export' do
      PersonalInformationLog.create!(error_class: 'OtherError', data: { other: 'data' })
      get '/admin/personal_information_logs/export', params: { error_class: 'TestError' }
      csv_data = response.body
      expect(csv_data).to include('TestError')
      expect(csv_data).not_to include('OtherError')
    end
  end

  describe 'auth routes' do
    it 'has a login route' do
      get '/admin/personal_information_logs/login'
      # In test mode without auth configured, should redirect to index
      expect(response).to redirect_to(admin_personal_information_logs_path)
    end

    it 'has a logout route' do
      get '/admin/personal_information_logs/logout'
      expect(response).to redirect_to(admin_personal_information_logs_path)
    end
  end
end

RSpec.describe Admin::PersonalInformationLogsController, type: :controller do
  describe 'team-based filtering' do
    let(:controller_instance) { described_class.new }

    describe '#pattern_to_sql_condition' do
      it 'handles exact match patterns' do
        condition = controller_instance.send(:pattern_to_sql_condition, 'ClaimsApi::Test')
        expect(condition).to eq("error_class = 'ClaimsApi::Test'")
      end

      it 'handles wildcard prefix patterns' do
        condition = controller_instance.send(:pattern_to_sql_condition, 'ClaimsApi::*')
        expect(condition).to eq("error_class LIKE 'ClaimsApi::%'")
      end

      it 'handles regex patterns' do
        condition = controller_instance.send(:pattern_to_sql_condition, '/^Claims/')
        expect(condition).to eq("error_class ~ '^Claims'")
      end
    end
  end
end
