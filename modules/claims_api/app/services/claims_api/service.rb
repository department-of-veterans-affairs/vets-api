# frozen_string_literal: true

require 'lib/claims_api/v2/error/error_base'

module ClaimsApi
  class Service
    def self.process(**args)
      new(args).process
    end

    def log_service_progress(claim_id, tag, detail)
      log_tag = tag == 'pdf' ? '526_v2_PDF_Generator_job' : '526_v2_Docker_Container_job'
      ClaimsApi::Logger.log(self.class,
                            log_tag:,
                            claim_id:,
                            detail:)
    end

    protected

    def save_auto_claim!(auto_claim, status)
      auto_claim.status = status
      auto_claim.validation_method = ClaimsApi::AutoEstablishedClaim::VALIDATION_METHOD
      auto_claim.save!
    end

    def evss_mapper_service(auto_claim, file_number)
      ClaimsApi::V2::DisabilityCompensationEvssMapper.new(auto_claim, file_number)
    end

    def veteran_file_number(auto_claim)
      auto_claim.auth_headers['va_eauth_birlsfilenumber']
    end

    def evss_service
      ClaimsApi::EVSSService::Base.new
    end

    def get_claim(claim_id)
      ClaimsApi::AutoEstablishedClaim.find(claim_id)
    end

    def set_errored_state_on_claim(auto_claim)
      save_auto_claim!(auto_claim, ClaimsApi::AutoEstablishedClaim::ERRORED)
    end

    def error_base(error)
      ClaimsApi::V2::Error::ErrorBase.new(error)
    end

    def set_error_response(auto_claim)
      auto_claim.evss_response = error_base(e).get_error_message
      auto_claim.save
    end
  end
end
