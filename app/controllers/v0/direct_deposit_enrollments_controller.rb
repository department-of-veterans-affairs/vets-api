module V0
  class DirectDepositEnrollmentsController < ApplicationController

    FORM_ID = '24-0296'
    
    skip_before_action(:authenticate)
    before_action(:tag_rainbows)
  
    def create

      enrollmentForm = SavedClaim::DirectDeposit.new(form: dd_params)
      
      unless enrollmentForm.valid?
        render(text: "Bad Request", status: :bad_request) and return      
      end

      unless enrollmentForm.save        
        raise Common::Exceptions::ValidationErrors, enrollmentForm
      end

      Rails.logger.info "DirectDepositEnrollmentID=#{enrollmentForm.id} RPO=#{enrollmentForm.regional_office}"

      # authenticate_token
      render(json: enrollmentForm)

    end

    private

    def dd_params
      # OliveBranch middleware mucks up the json in params, so get the raw data posted instead
      request.raw_post
    end
    
  end

end
