# frozen_string_literal: true

# TEST FILE: Service changes that should NOT be allowed with migrations
# For testing the MigrationIsolator Dangerfile changes
# DO NOT MERGE THIS FILE - For testing only

module Claims
  class StatusUpdaterTest
    def initialize(claim)
      @claim = claim
    end
    
    def process!
      # Business logic that depends on new columns
      @claim.processing_status = 'in_progress'
      @claim.processed_at = Time.current
      @claim.save!
      
      # External API call
      result = submit_to_lighthouse
      
      if result.success?
        @claim.update!(processing_status: 'completed')
        notify_veteran
      else
        @claim.update!(processing_status: 'failed')
        create_error_record(result.errors)
      end
    end
    
    private
    
    def submit_to_lighthouse
      # External service integration
      LighthouseService.submit(@claim)
    end
    
    def notify_veteran
      ClaimStatusMailer.completed(@claim).deliver_later
    end
    
    def create_error_record(errors)
      ClaimError.create!(
        claim: @claim,
        errors: errors,
        occurred_at: Time.current
      )
    end
  end
end