# frozen_string_literal: true
# 
# TODO: 
# DO NOT REVIEW THIS FILE AS IT WOULD BE DELETED IN SPRINT 3 
# DUE TO 526 and 4142 SUBMIT INTEGRATION 
#

module V0
  class PrivateMedicalRecordsController < ApplicationController
    skip_before_action :authenticate

    FORM_ID = '21-4142'

    # Use Submit Function to demonstrate PDF Generation in Isolation
    def submit
      make_pdf
    end

    # Use this Submit Function for Production
    # def submit
    #   form_content = populate_form_content
    #
    #   if form_content.empty?
    #     render json: { data: { attributes: { job_id: 'NA' } } },
    #            status: :ok
    #   else
    #     # save the claim
    #     claim = SavedClaim::PrivateMedicalRecord.new(form: form_content.to_json)
    #     unless claim.save
    #       StatsD.increment("#{stats_key}.failure")
    #       raise Common::Exceptions::ValidationErrors, claim
    #     end
    #     StatsD.increment("#{stats_key}.success")
    #
    #     Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
    #
    #     jid = 0
    #     # jid = CentralMail::SubmitForm4142Job.perform_async(
    #     #   @current_user.uuid, form_content, claim
    #     # )
    #
    #     render json: { data: { attributes: { job_id: jid } } },
    #            status: :ok
    #   end
    # end

    def make_pdf
      form_content = populate_form_content

      if form_content.empty?
        render json: { "message": 'Unable to find form data' }, status: :ok
      else
        file_path = fill_ancillary_form(form_content, '12345678')

        render json: { "message": file_path }, status: :ok
        # render pdf: file_path, status: :ok
      end
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

    def fill_ancillary_form(form_data, claim_id)
      form_class = PdfFill::Forms::Va214142

      folder = 'tmp/pdf'
      FileUtils.mkdir_p(folder)
      file_path = "#{folder}/#{FORM_ID}_#{claim_id}.pdf"

      hash_converter = PdfFill::HashConverter.new(form_class.date_strftime)

      new_hash = hash_converter.transform_data(
        form_data: form_class.new(form_data).merge_fields,
        pdftk_keys: form_class::KEY
      )

      PdfFill::Filler::PDF_FORMS.fill_form(
        "lib/pdf_fill/forms/pdfs/#{FORM_ID}.pdf",
        file_path,
        new_hash,
        flatten: false
      )

      PdfFill::Filler.combine_extras(file_path, hash_converter.extras_generator)

      file_path
    end
  end
end
