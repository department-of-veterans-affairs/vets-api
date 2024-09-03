# frozen_string_literal: true

module SignIn
  class ServiceAccountConfigsController < ServiceAccountApplicationController
    service_tag 'identity'
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    before_action :set_service_account_config, only: %i[show update destroy]

    def index
      service_account_configs = ServiceAccountConfig.where(service_account_id: params[:service_account_ids])

      render json: service_account_configs, status: :ok
    end

    def show
      render json: @service_account_config, status: :ok
    end

    def create
      service_account_config = ServiceAccountConfig.new(service_account_config_params)

      if service_account_config.save
        render json: service_account_config, status: :created
      else
        render json: { errors: service_account_config.errors }, status: :unprocessable_entity
      end
    end

    def update
      if @service_account_config.update(service_account_config_params)
        render json: @service_account_config, status: :ok
      else
        render json: { errors: @service_account_config.errors }, status: :unprocessable_entity
      end
    end

    def destroy
      if @service_account_config.destroy
        head :no_content
      else
        render json: { errors: @service_account_config.errors }, status: :unprocessable_entity
      end
    end

    private

    def service_account_config_params
      params.require(:service_account_config).permit(:service_account_id,
                                                     :description,
                                                     :access_token_audience,
                                                     :access_token_duration,
                                                     scopes: [],
                                                     certificates: [],
                                                     access_token_user_attributes: [])
    end

    def set_service_account_config
      @service_account_config = ServiceAccountConfig.find_by!(service_account_id: params[:service_account_id])
    end

    def not_found
      render json: { errors: { service_account_config: ['not found'] } }, status: :not_found
    end
  end
end
