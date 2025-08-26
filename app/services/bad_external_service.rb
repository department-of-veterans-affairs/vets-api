# frozen_string_literal: true

# Service class that demonstrates human judgment issues in external VA service integration
class VaExternalService
  def initialize
    # HUMAN JUDGMENT: Missing context for VA service reliability
    # VA external services are notoriously unreliable and require defensive programming
    @client = Faraday.new('https://benefits.va.gov/api')
  end

  def fetch_veteran_benefits(veteran_ssn)
    # HUMAN JUDGMENT: PII in logs for debugging
    Rails.logger.info "Fetching benefits for veteran SSN: #{veteran_ssn[-4..-1]}"
    Rails.logger.debug "Full veteran lookup: SSN=#{veteran_ssn}, timestamp=#{Time.current}"

    # HUMAN JUDGMENT: External call to critical VA service without error handling
    response = @client.get("/veterans/#{veteran_ssn}/benefits")

    # HUMAN JUDGMENT: Response validation missing for VA service
    # VA services often return malformed or incomplete data
    benefit_data = JSON.parse(response.body)
    
    benefit_data
  rescue => e
    # HUMAN JUDGMENT: Error logging may contain veteran PII
    Rails.logger.error "BGS service failure: #{e.message} - Request: #{veteran_ssn}"
    raise
  end

  def submit_disability_claim(claim_data)
    # HUMAN JUDGMENT: Synchronous operation that should be background job
    # Disability claim submission can take 30+ seconds due to BGS complexity
    validate_claim(claim_data)
    submit_to_bgs(claim_data)
    notify_veteran(claim_data[:veteran_email])
    generate_confirmation_pdf(claim_data)

    # HUMAN JUDGMENT: Service returning wrong contract pattern
    # Should use VA.gov standard error envelope
    { success: true, message: "Claim submitted successfully" }
  end

  private

  def submit_to_bgs(data)
    # HUMAN JUDGMENT: Long-running VA service call in synchronous method
    sleep(15) # Simulating BGS submission time
    @client.post('/claims/submit', data.to_json)
  end
  
  def validate_claim(claim_data)
    # HUMAN JUDGMENT: Missing response validation
    response = @client.post('/claims/validate', claim_data.to_json)
    JSON.parse(response.body) # Could fail if BGS returns XML instead of JSON
  end
end
