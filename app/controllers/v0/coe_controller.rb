# frozen_string_literal: true

require 'lgy/service'

module V0
  class CoeController < ApplicationController
    def status
      coe_status = lgy_service.coe_status
      render json: { data: { attributes: coe_status } }, status: :ok
    end

    def download_coe
      coe_url = lgy_service.coe_url
      render json: { data: { attributes: { url: coe_url } } }, status: :ok
    end

    def submit_coe_claim
      load_user
      claim = SavedClaim::CoeClaim.new(form: filtered_params[:form])

      unless claim.save
        StatsD.increment("#{stats_key}.failure")
        Raven.tags_context(team: 'vfs-ebenefits') # tag sentry logs with team name
        raise Common::Exceptions::ValidationErrors, claim
      end

      claim.send_to_lgy(edipi: current_user.edipi, icn: current_user.icn)

      Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
      clear_saved_form(claim.form_id)
      render(json: claim)
    end

    def documents
      documents = lgy_service.get_coe_documents
      render json: { data: { attributes: documents.body } }, status: :ok
    end

    def document_upload
      load_user

      attachments.each do |attachment|
        file_extension = attachment['file_type']

        if %w[jpg jpeg png pdf].include? file_extension.downcase
          file_data = attachment['file']
          index = file_data.index(';base64,') || 0
          file_data = file_data[index + 8..] if index.positive?

          document_data = {
            'documentType' => file_extension,
            'description' => attachment['document_type'],
            'contentsBase64' => file_data,
            'fileName' => attachment['file_name']
          }

          response = lgy_service.post_document(payload: document_data)
          render(json: response.status)
        end
      end
    end

    private

    def lgy_service
      @lgy_service ||= LGY::Service.new(edipi: @current_user.edipi, icn: @current_user.icn)
    end

    def filtered_params
      params.require(:lgy_coe_claim).permit(:form)
    end

    def attachments
      params[:files]
    end

    def stats_key
      'api.lgy_coe'
    end
  end
end
