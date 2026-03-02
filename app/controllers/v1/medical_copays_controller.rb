# frozen_string_literal: true

module V1
  class MedicalCopaysController < ApplicationController
    service_tag 'debt-resolution'
    before_action :authorize_icn
    rescue_from MedicalCopays::LighthouseIntegration::Service::ServiceError, with: :service_error

    def index
      if current_user.cerner_facility_ids.any?
        copays = vbs_service.get_copays
        copays[:isCerner] = true

        render json: copays
      else
        invoice_bundle = medical_copay_service.list_months
        serialized = Lighthouse::HCC::InvoiceSerializer.new(
          invoice_bundle.entries, links: invoice_bundle.links, meta: invoice_bundle.meta
        ).serializable_hash

        render json: serialized.merge(isCerner: false)
      end
    end

    def summary
      result = medical_copay_service.summary(
        month_count: params[:months]&.to_i || 6
      )

      render json: Lighthouse::HCC::InvoiceSerializer.new(
        result[:entries],
        meta: result[:meta]
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

    def service_error
      render json: { error: 'External service error' }, status: :bad_gateway
    end

    def authorize_icn
      raise Common::Exceptions::Forbidden, detail: 'User ICN is required' if current_user.icn.blank?
    end

    def vbs_service
      MedicalCopays::VBS::Service.build(user: current_user)
    end
  end
end
