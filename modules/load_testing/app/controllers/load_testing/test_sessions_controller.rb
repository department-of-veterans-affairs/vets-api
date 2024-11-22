module LoadTesting
  class TestSessionsController < ApplicationController
    def create
      test_session = TestSession.create!(
        concurrent_users: params[:concurrent_users],
        status: 'pending'
      )
      
      TokenManager.new(test_session).generate_tokens(params[:concurrent_users])
      
      RunTestJob.perform_async(test_session.id)
      
      render json: test_session, status: :created
    end

    def show
      test_session = TestSession.find(params[:id])
      render json: test_session
    end

    def index
      test_sessions = TestSession.order(created_at: :desc)
      render json: test_sessions
    end
  end
end 