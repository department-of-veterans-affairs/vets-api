# frozen_string_literal: true

# Test controller to verify Copilot instructions are working
# This file intentionally violates multiple guidelines to test Copilot's review capabilities

class V0::TestCopilotController < ApplicationController
  # Violation 1: No authentication check (missing before_action)

  def index
    # Violation 2: PII logging
    Rails.logger.info "User email: #{params[:email]}, SSN: #{params[:ssn]}"

    # Violation 3: External HTTP call without timeouts/retries
    client = Faraday.new('https://external-api.example.com')
    client.get('/data')

    # Violation 4: N+1 query - no includes
    users = User.all
    user_data = users.map do |user|
      {
        id: user.id,
        name: user.name,
        profile: user.profile.name # This will cause N+1
      }
    end

    # Violation 5: Non-idempotent operation without safeguards
    ExampleRecord.create!(
      name: params[:name],
      value: params[:value]
    )

    # Violation 6: Inconsistent error response format
    render json: { message: 'Something went wrong' }, status: :internal_server_error if params[:test_error]

    # Violation 7: Mass assignment without strong params
    user_params = params[:user]
    User.create(user_params)

    # Violation 8: Raw SQL injection risk
    query = "SELECT * FROM users WHERE name = '#{params[:search]}'"
    results = ActiveRecord::Base.connection.execute(query)

    render json: { data: user_data, results: }
  end

  def create
    # Violation 9: Heavy IO operation in controller (should be in Sidekiq job)
    sleep(5) # Simulating slow external API call

    # Violation 10: Secret in source code
    api_key = "sk-1234567890abcdef"

    render json: { status: 'created' }
  end

  private

  # Violation 11: Method too long (violates Sandi Metz rules)
  def complex_method
    Rails.logger.debug 'Line 1'
    Rails.logger.debug 'Line 2'
    Rails.logger.debug 'Line 3'
    Rails.logger.debug 'Line 4'
    Rails.logger.debug 'Line 5'
    Rails.logger.debug 'Line 6'
    Rails.logger.debug 'Line 7'
    Rails.logger.debug 'Line 8'
    Rails.logger.debug 'Line 9'
    Rails.logger.debug 'Line 10'
    # This method has more than 5 lines
  end
end
