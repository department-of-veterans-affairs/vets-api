require_relative 'application_job'

module LoadTesting
  class LoadTestJob < LoadTesting::ApplicationJob
    queue_as :load_testing

    def perform(test_session_id)
      Rails.logger.info("Starting load test for session #{test_session_id}")
      test_session = TestSession.find(test_session_id)
      
      begin
        Rails.logger.info("Updating test session status to running")
        test_session.update!(
          status: 'running', 
          started_at: Time.current
        )
        
        Rails.logger.info("Test session #{test_session_id} is ready for k6 testing")
        Rails.logger.info("Run the following command in a separate terminal:")
        Rails.logger.info(generate_k6_command(test_session))
        
      rescue StandardError => e
        Rails.logger.error("Failed to prepare test session: #{e.message}")
        test_session.update!(
          status: 'failed',
          completed_at: Time.current,
          results: { error: e.message }
        )
        raise e
      end
    end

    private

    def generate_k6_command(test_session)
      script_path = Rails.root.join('modules', 'load_testing', 'scripts', 'scenarios', 'full_auth_flow.js')
      
      # Use default credentials if settings not available
      credentials = {
        email: ENV['LOAD_TEST_LOGIN_EMAIL'] || 'vets.gov.user+1@gmail.com',
        password: ENV['LOAD_TEST_LOGIN_PASSWORD'] || 'Password12345!'
      }

      command = [
        'k6 run',
        script_path.to_s,
        "--env SESSION_ID=#{test_session.id}",
        "--env API_BASE_URL=http://localhost:3000",
        "--env LOGIN_EMAIL=#{credentials[:email]}",
        "--env LOGIN_PASSWORD=#{credentials[:password]}",
        "--env STAGES='#{test_session.configuration['stages'].to_json}'",
        "--vus #{test_session.concurrent_users}"
      ].join(' ')

      Rails.logger.info("Generated k6 command: #{command}")
      command
    end
  end
end 