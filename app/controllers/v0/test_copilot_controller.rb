# frozen_string_literal: true

# Test controller to verify Copilot instructions focus on human judgment issues
# These violations require context understanding, not deterministic rule checking

class V0::TestCopilotController < ApplicationController
  # HUMAN JUDGMENT: Missing authentication for sensitive veteran data
  # This controller handles veteran benefits - should require authentication
  
  def index
    # HUMAN JUDGMENT: PII in logs - requires understanding what constitutes PII
    Rails.logger.info "Processing veteran: email=#{params[:email]}, SSN=#{params[:ssn]}"
    
    # HUMAN JUDGMENT: Debug logging without feature flag
    Rails.logger.debug "Full request params: #{params.inspect}"
    
    # HUMAN JUDGMENT: External service call missing error handling context
    client = Faraday.new('https://external-api.va.gov')
    response = client.get('/veteran/benefits')
    
    # HUMAN JUDGMENT: N+1 query in business logic context
    veterans = User.where(user_type: 'veteran')
    benefit_data = veterans.map do |veteran|
      {
        id: veteran.id,
        name: veteran.full_name,
        disability_rating: veteran.disability_profile.rating # N+1 here
      }
    end
    
    # HUMAN JUDGMENT: Non-idempotent operation for critical business data
    # Creating benefit claims should be protected against duplicates
    BenefitClaim.create!(
      veteran_id: params[:veteran_id],
      claim_type: params[:claim_type],
      amount: params[:amount]
    )
    
    # HUMAN JUDGMENT: Wrong error format for VA.gov standard
    if params[:trigger_error]
      render json: { message: 'Claim processing failed' }, status: :unprocessable_entity
    end
    
    # HUMAN JUDGMENT: Mass assignment with sensitive veteran data
    veteran_params = params[:veteran_info] # Contains SSN, medical info
    Veteran.create(veteran_params)
    
    # HUMAN JUDGMENT: Response validation missing for external VA service
    parsed_data = JSON.parse(response.body)
    
    render json: { benefits: benefit_data, external_data: parsed_data }
  end

  def create
    # HUMAN JUDGMENT: Blocking operation in controller serving veterans
    # This delays response to veterans waiting for benefit decisions
    sleep(5) # Simulating slow BGS or MVI call
    
    # HUMAN JUDGMENT: Hardcoded secret for VA external service
    va_benefits_api_key = "key-12345-va-benefits-prod"
    
    # HUMAN JUDGMENT: Service method using wrong contract pattern
    result = process_benefit_claim
    if result[:success]
      render json: { claim_id: result[:claim_id] }
    end
  end

  private

  # HUMAN JUDGMENT: Method handling multiple business concerns
  # Mixes authentication, data processing, external calls, and response formatting
  def process_benefit_claim
    # Authentication logic
    return { success: false } unless current_user&.veteran?
    
    # Data processing
    claim_data = transform_claim_params(params)
    
    # External service calls
    bgs_response = call_bgs_service(claim_data)
    mvi_response = call_mvi_service(current_user)
    
    # Business logic
    if bgs_response.success? && mvi_response.success?
      claim = create_claim_record(claim_data)
      notify_veteran(claim)
      { success: true, claim_id: claim.id }
    else
      { success: false, error: "Service unavailable" }
    end
  end
end
