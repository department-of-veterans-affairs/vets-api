module MyHealth
  module V1
    class TooltipsController < ApplicationController
      before_action :set_user_account, only: [:index, :create, :update]
      before_action :set_tooltip, only: [:update]
      service_tag 'mhv-messaging'

      def index
        tooltips = @user_account.tooltips
        render json: tooltips
      end

      def create
        begin
          tooltip = @user_account.tooltips.build(tooltip_params)
          tooltip.last_signed_in = current_user.last_signed_in
          tooltip.save!
          render json: tooltip, status: :created
        rescue ActiveRecord::RecordInvalid => e
          render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
        rescue StandardError => e
          log_and_render_error(e, "Error creating tooltip")
        end
      end

      def update
        unless params[:tooltip].present?
          render json: { error: "Request body must contain a 'tooltip' object." }, status: :bad_request
          return
        end

        if @tooltip.update(tooltip_params)
          if params[:tooltip][:increment_counter] == 'true'
            # Check for session uniqueness before incrementing. Business logic: if there are 3 unique sessions the hidden counter will be switched to true, purpose is to hide the tooltip in the view.
            if @tooltip.last_signed_in != current_user.last_signed_in
              @tooltip.counter += 1
              @tooltip.last_signed_in = current_user.last_signed_in
              @tooltip.hidden = true if @tooltip.counter >= 3
              @tooltip.save
            end
          end
          # User can choose to hide the tooltip before reaching 3 unique sessions.
          @tooltip.update(hidden: params[:tooltip][:hidden]) if params[:tooltip][:hidden].present?
          render json: @tooltip
        else
          render json: { errors: @tooltip.errors.full_messages }, status: :unprocessable_entity
        end

      rescue ActiveRecord::RecordNotFound => e
        log_and_render_error(e, "Tooltip not found")
      rescue ActiveRecord::RecordInvalid => e
        log_and_render_error(e, "Invalid tooltip data")
      rescue StandardError => e
        log_and_render_error(e, "Error updating tooltip")
      end

      private

      def log_and_render_error(exception, message)
        Rails.logger.error("#{message}: #{exception.message}\n#{exception.backtrace.join("\n")}")
        render json: { error: message }, status: :internal_server_error
      end

      def set_tooltip
        @tooltip = @user_account.tooltips.find_by(id: params[:id])
        render json: { error: 'Tooltip not found' }, status: :not_found unless @tooltip
      end

      # only allow the tooltip_name and hidden attributes to be modified via params object.
      def tooltip_params
        params.require(:tooltip).permit(:tooltip_name, :hidden)
      end

      def increment_counter_if_new_session(tooltip)
        if tooltip.last_signed_in != current_user.last_signed_in
          tooltip.counter += 1
          tooltip.last_signed_in = current_user.last_signed_in
          tooltip.hidden = true if tooltip.counter >= 3
          tooltip.save
        end
      end

      def set_user_account
        @user_account = current_user.user_account
        if @user_account.nil?
          render json: { error: 'User account not found' }, status: :not_found
        end
      end

      def log_and_render_error(exception, message)
        Rails.logger.error("#{message}: #{exception.message}\n#{exception.backtrace.join("\n")}")
        render json: { error: message }, status: :internal_server_error
      end
    end
  end
end