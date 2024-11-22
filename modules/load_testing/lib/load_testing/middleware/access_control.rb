module LoadTesting
  module Middleware
    class AccessControl
      def initialize(app)
        @app = app
      end

      def call(env)
        Rails.logger.info "=== Load Testing Access Control ==="
        Rails.logger.info "Current Rails Environment: #{Rails.env}"
        Rails.logger.info "Development?: #{Rails.env.development?}"
        Rails.logger.info "Test?: #{Rails.env.test?}"
        Rails.logger.info "Path: #{env['PATH_INFO']}"
        Rails.logger.info "==================================="

        if Rails.env.development? || Rails.env.test?
          Rails.logger.info "Bypassing auth in development/test"
          return @app.call(env)
        end

        unless authorized?(env)
          Rails.logger.info "Authorization failed"
          return forbidden_response
        end

        Rails.logger.info "Authorization successful"
        @app.call(env)
      end

      private

      def authorized?(env)
        request = Rack::Request.new(env)
        path_check = request.path.start_with?('/load_testing')
        Rails.logger.info "Path check: #{path_check} for path: #{request.path}"
        
        return false unless path_check
        
        # Check if user is in identity team
        user = request.env['warden'].user
        Rails.logger.info "User present: #{user.present?}"
        user&.identity_team_member?
      end

      def forbidden_response
        [403, { 'Content-Type' => 'application/json' }, [{ error: 'Unauthorized access' }.to_json]]
      end
    end
  end
end 