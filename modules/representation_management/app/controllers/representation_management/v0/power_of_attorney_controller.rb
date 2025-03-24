# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module RepresentationManagement
  module V0
    class PowerOfAttorneyController < ApplicationController
      service_tag 'representation-management'
      before_action { authorize :power_of_attorney, :access? }

      def index
        @active_poa = lighthouse_service.get_power_of_attorney

        if @active_poa.blank? || record.blank?
          render json: { data: {} }, status: :ok
        else
          render json: serializer.new(record), status: :ok
        end
      end

      private

      def lighthouse_service
        BenefitsClaims::Service.new(icn)
      end

      def icn
        @current_user&.icn
      end

      def poa_code
        @poa_code ||= @active_poa.dig('data', 'attributes', 'code')
      end

      def poa_type
        @poa_type ||= @active_poa.dig('data', 'type')
      end

      def record
        return @record if defined? @record

        @record ||= if poa_type == 'organization'
                      organization
                    else
                      representative
                    end
      end

      def serializer
        if poa_type == 'organization'
          RepresentationManagement::PowerOfAttorney::OrganizationSerializer
        else
          RepresentationManagement::PowerOfAttorney::RepresentativeSerializer
        end
      end

      def organization
        Veteran::Service::Organization.find_by(poa: poa_code)
      end

      def representative
        Veteran::Service::Representative.where('? = ANY(poa_codes)', poa_code).order(created_at: :desc).first
      end
    end
  end
end
