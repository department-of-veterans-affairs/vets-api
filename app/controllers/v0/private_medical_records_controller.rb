# frozen_string_literal: true

module V0
  class PrivateMedicalRecordsController < ApplicationController
    FORM_ID = '21-4142'
    
    def submit
      form_content = JSON.parse(request.body.string)
      
      #TODO uncomment below line to support submission during 526 integration
      #form_content = InProgressForm.form_for_user(FORM_ID, @current_user) ? if form_content.empty?
      
      # save the claim
      claim = SavedClaim::PrivateMedicalRecord.new(form: form_content.to_json)
      unless claim.save
        StatsD.increment("#{stats_key}.failure")
        raise Common::Exceptions::ValidationErrors, claim
      end
      StatsD.increment("#{stats_key}.success")
      
      Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"

      jid = CentralMail::SubmitForm4142Job.perform_async(
        @current_user.uuid, form_content, claim
      )

      render json: { data: { attributes: { job_id: jid } } },
             status: :ok
    end
    
    def submission_status
      submission = AsyncTransaction::CentralMail::VA4142SubmitTransaction.find_transaction(params[:@current_user.uuid, :job_id])
      raise Common::Exceptions::RecordNotFound, params[:job_id] unless submission
      render json: submission, serializer: AsyncTransaction::BaseSerializer
    end
    
    def stats_key
      'api.private_medical_records'
    end
  
  end
end
