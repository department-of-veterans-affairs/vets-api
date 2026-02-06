# frozen_string_literal: true

module V1
  class MedicalCopaysController < ApplicationController
    service_tag 'debt-resolution'

    def index
      invoice_bundle = medical_copay_service.list_months

      render json: Lighthouse::HCC::InvoiceSerializer.new(
        invoice_bundle.entries, links: invoice_bundle.links, meta: invoice_bundle.meta
      )
    end

    def show
      copay_detail = medical_copay_service.get_detail(id: params[:id])

      render json: Lighthouse::HCC::CopayDetailSerializer.new(copay_detail)
    end

    private

    def medical_copay_service
      MedicalCopays::LighthouseIntegration::Service.new(current_user.icn)
    end
  end
end
