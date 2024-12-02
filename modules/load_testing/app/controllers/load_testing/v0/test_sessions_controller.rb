module LoadTesting
  module V0
    class TestSessionsController < ApplicationController
      include ActionController::Live
      
      # Add timeout for slow requests
      rescue_from Timeout::Error do |e|
        render json: { error: 'Request timed out' }, status: :request_timeout
      end

      def create
        Timeout.timeout(5) do  # 5 second timeout
          configuration = {
            client_id: params[:client_id],
            type: params[:type],
            acr: params[:acr],
            stages: params[:stages]
          }

          test_session = LoadTesting::TestSession.new(
            concurrent_users: params[:concurrent_users],
            configuration: configuration,
            status: 'pending'
          )

          if test_session.save
            token_manager = LoadTesting::TokenManager.new(test_session)
            token_manager.generate_tokens(test_session.concurrent_users)
            
            render json: test_session, status: :created
          else
            render json: { errors: test_session.errors.full_messages }, status: :unprocessable_entity
          end
        end
      end

      def show
        Timeout.timeout(5) do
          test_session = TestSession.find(params[:id])
          render json: test_session
        end
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

      def tokens
        Timeout.timeout(5) do
          test_session = TestSession.find(params[:id])
          render json: test_session.test_tokens.available
        end
      end

      private

      def test_session_params
        params.permit(
          :concurrent_users,
          :client_id,
          :type,
          :acr,
          stages: [:duration, :target]
        )
      end
    end
  end
end 