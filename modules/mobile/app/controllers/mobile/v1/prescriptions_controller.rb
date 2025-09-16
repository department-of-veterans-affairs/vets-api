# frozen_string_literal: true

module Mobile
  module V1
    class PrescriptionsController < ApplicationController
      before_action :authenticate_user!
      before_action :validate_feature_flag

      def index
        # Mobile-specific pagination parameters
        page = params[:page]&.to_i || 1
        per_page = params[:per_page]&.to_i || 20
        per_page = [per_page, 50].min # Cap at 50 for mobile performance

        # Mobile-specific filters
        refill_status = params[:refill_status]
        sort = params[:sort] || '-dispensed_date'

        begin
          # Use UHD service for all data transformation
          prescriptions = UnifiedHealthData::Service.get_prescriptions(
            user: current_user,
            page:,
            per_page:,
            refill_status:,
            sort:
          )

          # Generate mobile-specific metadata
          metadata = generate_mobile_metadata(prescriptions)

          render json: {
            data: prescriptions,
            meta: {
              pagination: {
                current_page: page,
                per_page:,
                total_pages: metadata[:total_pages],
                total_entries: metadata[:total_entries]
              },
              **metadata[:mobile_specific]
            }
          }, serializer: Mobile::V1::PrescriptionsSerializer
        rescue => e
          Rails.logger.error "Mobile V1 Prescriptions API error: #{e.message}"
          render json: {
            error: {
              code: 'PRESCRIPTION_SERVICE_ERROR',
              message: 'Unable to retrieve prescriptions at this time'
            }
          }, status: :service_unavailable
        end
      end

      def show
        prescription_id = params[:id]

        begin
          prescription = UnifiedHealthData::Service.get_prescription(
            user: current_user,
            prescription_id:
          )

          if prescription
            render json: prescription, serializer: Mobile::V1::PrescriptionsSerializer
          else
            render json: {
              error: {
                code: 'PRESCRIPTION_NOT_FOUND',
                message: 'Prescription not found'
              }
            }, status: :not_found
          end
        rescue => e
          Rails.logger.error "Mobile V1 Prescription detail error: #{e.message}"
          render json: {
            error: {
              code: 'PRESCRIPTION_SERVICE_ERROR',
              message: 'Unable to retrieve prescription details at this time'
            }
          }, status: :service_unavailable
        end
      end

      def refill
        prescription_id = params[:id]

        begin
          result = UnifiedHealthData::Service.refill_prescription(
            user: current_user,
            prescription_id:
          )

          if result[:success]
            render json: {
              data: {
                prescription_id:,
                refill_status: result[:refill_status],
                refill_date: result[:refill_date]
              }
            }, status: :ok
          else
            render json: {
              error: {
                code: 'REFILL_FAILED',
                message: result[:error] || 'Unable to process refill request'
              }
            }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error "Mobile V1 Prescription refill error: #{e.message}"
          render json: {
            error: {
              code: 'REFILL_SERVICE_ERROR',
              message: 'Unable to process refill request at this time'
            }
          }, status: :service_unavailable
        end
      end

      private

      def validate_feature_flag
        unless Flipper.enabled?(:mobile_prescriptions_v1, current_user)
          render json: {
            error: {
              code: 'FEATURE_NOT_AVAILABLE',
              message: 'This feature is not currently available'
            }
          }, status: :forbidden
        end
      end

      def generate_mobile_metadata(prescriptions)
        # Calculate mobile-specific metadata
        total_entries = prescriptions.is_a?(Array) ? prescriptions.length : 0
        total_pages = (total_entries.to_f / (params[:per_page]&.to_i || 20)).ceil

        # Prescription status counts for mobile dashboard
        status_counts = prescriptions.group_by(&:refill_status).transform_values(&:count)

        # Check for non-VA medications
        has_non_va_meds = prescriptions.any? { |rx| rx.prescription_source != 'va' }

        {
          total_entries:,
          total_pages:,
          mobile_specific: {
            prescriptionStatusCount: {
              active: status_counts['active'] || 0,
              expired: status_counts['expired'] || 0,
              transferred: status_counts['transferred'] || 0,
              submitted: status_counts['submitted'] || 0,
              hold: status_counts['hold'] || 0,
              discontinued: status_counts['discontinued'] || 0,
              pending: status_counts['pending'] || 0,
              unknown: status_counts['unknown'] || 0
            },
            hasNonVaMeds: has_non_va_meds
          }
        }
      end
    end
  end
end
