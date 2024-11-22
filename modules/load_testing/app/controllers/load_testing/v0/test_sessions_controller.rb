module LoadTesting
  module V0
    class TestSessionsController < ApplicationController
      def create
        test_session = TestSession.new(
          concurrent_users: params[:concurrent_users],
          status: 'pending',
          configuration: test_session_params
        )

        if test_session.save
          TokenManager.new(test_session).generate_tokens(test_session.concurrent_users)
          render json: test_session, status: :created
        else
          render json: { errors: test_session.errors.full_messages }, status: :unprocessable_entity
        end
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

      private

      def test_session_params
        params.permit(:concurrent_users, configuration: {}).tap do |whitelisted|
          whitelisted[:configuration] = params[:configuration] if params[:configuration].present?
        end
      end
    end
  end
end 