# frozen_string_literal: true

require 'va_profile/demographics/service'

module V0
  module Profile
    class PersonalInformationsController < ApplicationController
      service_tag 'profile'
      before_action { authorize :demographics, :access? }
      before_action { authorize :mpi, :queryable? }

      # Fetches the personal information for the current user.
      # Namely their gender, birth date, preferred name, and gender identity.
      def show
        response = service.get_demographics

        handle_errors!(response)

        render json: PersonalInformationSerializer.new(response), status: response.status
      end

      private

      def service
        VAProfile::Demographics::Service.new @current_user
      end

      def handle_errors!(response)
        raise_error! if response.gender.blank? && response.birth_date.blank?

        log_errors_for(response)
      end

      def raise_error!
        raise Common::Exceptions::BackendServiceException.new(
          'MVI_BD502',
          source: self.class.to_s
        )
      end

      def log_errors_for(response)
        return unless response.gender.nil? || response.birth_date.nil?

        Rails.logger.error("mpi missing data: #{I18n.t('common.exceptions.MVI_BD502.detail')}", {
                             response: sanitize_data(response.to_h),
                             params: sanitize_data(params),
                             gender: response.gender,
                             birth_date: response.birth_date,
                             mvi_status_code: I18n.t('common.exceptions.MVI_BD502.status')
                           })
      end

      def sanitize_data(data)
        data.except(
          :source_system_user,
          :address_line1,
          :address_line2,
          :address_line3,
          :city_name,
          :vet360_id,
          :county,
          :state_code,
          :zip_code5,
          :zip_code4,
          :phone_number,
          :country_code_iso3,
          :preferred_name
        )
      end
    end
  end
end
