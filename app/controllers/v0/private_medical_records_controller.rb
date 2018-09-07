# frozen_string_literal: true

#
# TODO:
# DO NOT REVIEW THIS FILE AS IT WOULD BE DELETED IN SPRINT 3
# WHEN THE 526 and 4142 SUBMIT INTEGRATION IS COMPLETED
# THIS ALSO DEMOS THE CONTRACT BETWEEN 526 AND 4142/4142A IN
# TERMS OF METHOD PARAMETERS SUPPORTED BY SubmitForm4142Job
#

module V0
  class PrivateMedicalRecordsController < ApplicationController
    FORM_ID = '21-4142'
    CLAIM_ID = '600033692'

    # Use Submit Function to demonstrate PDF Generation in Isolation
    def submit
      make_pdf
    end

    def make_pdf
      form_content = populate_form_content

      form_content = (File.read 'spec/support/ancillary_forms/submit_form4142.json') if form_content.empty?

      jid = CentralMail::SubmitForm4142Job.perform_async(
        @current_user.uuid, form_content, CLAIM_ID, Time.now.in_time_zone('Central Time (US & Canada)')
      )
      render json: { data: { attributes: { job_id: jid } } },
             status: :ok
    end

    def submission_status
      submission = AsyncTransaction::CentralMail::
                    VA4142SubmitTransaction.find_transaction(params[:@current_user.uuid, :job_id])
      raise Common::Exceptions::RecordNotFound, params[:job_id] unless submission
      render json: submission, serializer: AsyncTransaction::BaseSerializer
    end

    def stats_key
      'api.private_medical_records'
    end

    private

    def populate_form_content
      form_content = ''
      if !request.body.string.empty?
        form_content = JSON.parse(request.body.string)
      else
        form = InProgressForm.form_for_user(FORM_ID, @current_user)
        form_content = JSON.parse(form.form_data) unless form.nil?
      end
      form_content
    end
  end
end
