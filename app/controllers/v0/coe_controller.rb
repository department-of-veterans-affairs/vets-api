# frozen_string_literal: true

require 'lgy/service'

module V0
  class CoeController < ApplicationController
    def status
      coe_status = lgy_service.coe_status
      render json: { data: { attributes: coe_status } }, status: :ok
    end

    def download_coe
      res = lgy_service.get_coe_file

      send_data(res.body, type: 'application/pdf', disposition: 'attachment')
    end

    def submit_coe_claim
      claim = SavedClaim::CoeClaim.new(form: filtered_params[:form])

      unless claim.save
        StatsD.increment("#{stats_key}.failure")
        Raven.tags_context(team: 'vfs-ebenefits') # tag sentry logs with team name
        raise Common::Exceptions::ValidationErrors, claim
      end

      response = claim.send_to_lgy(edipi: current_user.edipi, icn: current_user.icn)

      Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
      clear_saved_form(claim.form_id)
      render json: { data: { attributes: { reference_number: response, claim: claim } } }
    end

    def documents
      documents = lgy_service.get_coe_documents.body
      # Vet-uploaded docs have documentType `Veteran Correspondence`. We are not
      # currently displaying these on the COE status page, so they are omitted.
      # In the near future, we will display them, and can remove this `reject`
      # block.
      notification_letters = documents.reject { |doc| doc['document_type']&.include?('Veteran Correspondence') }
      # Documents should be sorted from most to least recent
      sorted_notification_letters = notification_letters.sort_by { |doc| doc['create_date'] }.reverse
      render json: { data: { attributes: sorted_notification_letters } }, status: :ok
    end

    def document_upload
      status = 201

      # Each document is uploaded individually
      attachments.each do |attachment|
        file_extension = attachment['file_type']

        if %w[jpg jpeg png pdf].include? file_extension.downcase
          document_data = build_document_data(attachment)

          response = lgy_service.post_document(payload: document_data)
          unless response.status == 201
            status = response.status
            break
          end
        end
      end
      render(json: status)
    end

    def document_download
      res = lgy_service.get_document(params[:id])
      send_data(res.body, type: 'application/pdf', disposition: 'attachment')
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

    def build_document_data(attachment)
      file_data = attachment['file']
      index = file_data.index(';base64,') || 0
      file_data = file_data[index + 8..] if index.positive?

      {
        'documentType' => attachment['file_type'],
        'description' => attachment['document_type'],
        'contentsBase64' => file_data,
        'fileName' => attachment['file_name']
      }
    end
  end
end
