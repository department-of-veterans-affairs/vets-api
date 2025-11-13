# frozen_string_literal: true

module V1
  class MedicalCopaysController < ApplicationController
    service_tag 'debt-resolution'

    def index
      invoice_bundle = medical_copay_service.list(count: params[:count] || 10, page: params[:page] || 1)

      render json: Lighthouse::HCC::InvoiceSerializer.new(
        invoice_bundle.entries, links: invoice_bundle.links, meta: invoice_bundle.meta
      )
    end

    private

    def medical_copay_service
      MedicalCopays::LighthouseIntegration::Service.new(current_user.icn)
    end
  end
end
