# frozen_string_literal: true

# Service class that violates HTTP client guidelines
class BadExternalService
  def initialize
    # Violation 1: No timeouts specified
    # Violation 2: No retry logic
    # Violation 3: No error handling
    @client = Faraday.new('https://external-api.va.gov')
  end

  def fetch_user_data(user_id)
    # Violation 4: PII in logs
    Rails.logger.info "Fetching data for user SSN: #{user_id}"

    # Violation 5: No timeout, retry, or error handling on external call
    response = @client.get("/users/#{user_id}")

    # Violation 6: No validation of response
    JSON.parse(response.body)
  rescue => e
    # Violation 7: Logging full error which might contain PII
    Rails.logger.error "Full error: #{e.inspect}"
    raise
  end

  def create_record(data)
    # Violation 8: Should be in background job, not synchronous
    slow_external_call(data)

    # Return without proper error envelope
    { success: true }
  end

  private

  def slow_external_call(data)
    # Simulating a slow call that should be in Sidekiq
    sleep(10)
    @client.post('/records', data.to_json)
  end
end
