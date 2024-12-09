module LoadTesting
  module V0
    class TestSessionsController < ApplicationController
      include ActionController::Live
      
      rescue_from Timeout::Error do |e|
        render json: { error: 'Request timed out' }, status: :request_timeout
      end

      def create
        Timeout.timeout(5) do
          test_session = LoadTesting::TestSession.new(test_session_params)
          
          if test_session.save
            LoadTestJob.perform_later(test_session.id)
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

      def update
        test_session = TestSession.find(params[:id])
        
        if test_session.update(test_session_update_params)
          render json: test_session
        else
          render json: { errors: test_session.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def test_session_params
        # First, permit the stages array properly
        stages = params.dig(:configuration, :stages)&.map do |stage|
          stage.permit(:duration, :target).to_h
        end

        # Then create the configuration hash
        config = {
          client_id: 'load_test_client',
          type: params.dig(:configuration, :type) || 'logingov',
          acr_values: params.dig(:configuration, :acr_values) || 'min',
          stages: stages
        }.compact

        # Finally return the permitted params with our constructed configuration
        params.permit(:concurrent_users).merge(
          status: 'pending',
          configuration: config
        )
      end

      def test_session_update_params
        params.permit(:status, :completed_at, results: {})
      end
    end
  end
end 