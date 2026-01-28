# frozen_string_literal: true

module V0
  module Profile
    class SchedulingPreferencesController < ApplicationController
      before_action { authorize :vet360, :access? }
      before_action :check_feature_flag!
      before_action :check_pilot_access!

      service_tag 'profile'

      def show
        response = service.get_person_options(VAProfile::PersonSettings::Service::CONTAINER_IDS[:preferences])
        preferences_data = { preferences: VAProfile::Models::PersonOption.to_frontend_format(response.person_options) }

        render json: SchedulingPreferencesSerializer.new(preferences_data)
      end

      def create
        person_options_data = build_and_validate_person_options
        write_person_options_and_render_transaction!(person_options_data)
        Rails.logger.info('SchedulingPreferencesController#create request completed', sso_logging_info)
      end

      def update
        person_options_data = build_and_validate_person_options
        write_person_options_and_render_transaction!(person_options_data)
        Rails.logger.info('SchedulingPreferencesController#update request completed', sso_logging_info)
      end

      def destroy
        person_options_data = build_and_validate_person_options(action: :delete)
        write_person_options_and_render_transaction!(person_options_data)
        Rails.logger.info('SchedulingPreferencesController#destroy request completed', sso_logging_info)
      end

      private

      def check_feature_flag!
        unless Flipper.enabled?(:profile_scheduling_preferences, @current_user)
          raise Common::Exceptions::Forbidden, detail: 'Scheduling preferences not available'
        end
      end

      def check_pilot_access!
        visn_service = UserVisnService.new(@current_user)
        unless visn_service.in_pilot_visn?
          Rails.logger.info("Scheduling preferences not available for your facility for user #{@current_user.uuid}")
          raise Common::Exceptions::Forbidden, detail: 'Unable to verify access to scheduling preferences'
        end
      end

      def scheduling_preference_params
        params.permit(:item_id, option_ids: [])
      end

      def service
        @service ||= VAProfile::PersonSettings::Service.new(@current_user)
      end

      def build_and_validate_person_options(action: :create)
        raise Common::Exceptions::ParameterMissing, 'item_id' if scheduling_preference_params[:item_id].blank?
        raise Common::Exceptions::ParameterMissing, 'option_ids' if scheduling_preference_params[:option_ids].blank?

        person_options = VAProfile::Models::PersonOption.from_frontend_selection(
          scheduling_preference_params[:item_id],
          scheduling_preference_params[:option_ids]
        )

        person_options.each do |option|
          option.set_defaults(@current_user)
          option.mark_for_deletion if action == :delete
          validate!(option)
        end

        VAProfile::Models::PersonOption.to_api_payload(person_options)
      end

      def write_person_options_and_render_transaction!(person_options_data)
        response = service.update_person_options(person_options_data)
        transaction = AsyncTransaction::VAProfile::PersonOptionsTransaction.start(@current_user, response)
        render json: AsyncTransaction::BaseSerializer.new(transaction).serializable_hash
      end

      def validate!(person_option)
        return if person_option.valid?

        raise Common::Exceptions::ValidationErrors, person_option
      end
    end
  end
end
