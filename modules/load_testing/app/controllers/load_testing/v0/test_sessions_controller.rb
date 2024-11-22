module LoadTesting
  module V0
    class TestSessionsController < ApplicationController
      def create
        test_session = TestSession.create!(
          concurrent_users: params[:concurrent_users],
          status: 'pending',
          configuration: params.permit!.to_h
        )
        
        TokenManager.new(test_session).generate_tokens(params[:concurrent_users])
        
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

      def analysis
        test_session = TestSession.find(params[:id])
        analyzer = MetricsAnalyzer.new(test_session)
        render json: analyzer.analyze
      end
    end
  end
end 