# frozen_string_literal: true

module Mobile
  module V0
    class FacilitiesInfoController < ApplicationController
      SORT_METHODS = %w[home current alphabetical appointments].freeze

      before_action :validate_sort_method_inclusion!, only: %i[schedulable]
      before_action :validate_home_sort!, only: %i[schedulable], if: -> { params[:sort] == 'home' }
      before_action :validate_current_location_sort!, only: %i[schedulable], if: -> { params[:sort] == 'current' }

      def index
        facility_ids = @current_user.va_treatment_facility_ids
        facilities = Mobile::FacilitiesHelper.fetch_facilities_from_ids(@current_user, facility_ids,
                                                                        include_children: false, schedulable: nil)

        adapted_facilities = Mobile::V0::Adapters::FacilityInfo.new(@current_user).parse(facilities:)

        render json: Mobile::V0::FacilitiesInfoSerializer.new(adapted_facilities)
      end

      def schedulable
        facility_ids = (@current_user.va_treatment_facility_ids + @current_user.cerner_facility_ids).uniq

        facilities = Mobile::FacilitiesHelper.fetch_facilities_from_ids(@current_user, facility_ids,
                                                                        include_children: true, schedulable: true)

        facilities_info = Mobile::V0::Adapters::FacilityInfo.new(@current_user).parse(facilities:,
                                                                                      sort: params[:sort],
                                                                                      lat: params[:lat],
                                                                                      long: params[:long])

        render json: Mobile::V0::FacilitiesInfoSerializer.new(facilities_info)
      end

      private

      def validate_sort_method_inclusion!
        unless SORT_METHODS.include?(params[:sort])
          raise Common::Exceptions::InvalidFieldValue.new('sort', params[:sort])
        end
      end

      def validate_home_sort!
        home_address = @current_user.vet360_contact_info&.residential_address
        unless home_address&.latitude && home_address.longitude
          raise Common::Exceptions::UnprocessableEntity.new(
            detail: 'User has no home latitude and longitude', source: self.class.to_s
          )
        end
      end

      def validate_current_location_sort!
        params.require(:lat)
        params.require(:long)
      end
    end
  end
end
