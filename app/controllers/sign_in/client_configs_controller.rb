# frozen_string_literal: true

module SignIn
  class ClientConfigsController < SignIn::ApplicationController
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    skip_before_action :authenticate
    before_action :authenticate_service_account
    before_action :set_client_config, only: %i[show update destroy]

    def index
      client_configs = SignIn::ClientConfig.where(client_id: params[:client_ids])

      render json: client_configs, status: :ok
    end

    def show
      render json: @client_config, status: :ok
    end

    def create
      client_config = SignIn::ClientConfig.new(client_config_params)

      if client_config.save
        render json: client_config, status: :created
      else
        render json: client_config.errors, status: :unprocessable_entity
      end
    end

    def update
      if @client_config.update(client_config_params)
        render json: @client_config, status: :ok
      else
        render json: @client_config.errors, status: :unprocessable_entity
      end
    end

    def destroy
      if @client_config.destroy
        head :no_content
      else
        render json: @client_config.errors, status: :unprocessable_entity
      end
    end

    private

    def client_config_params
      params.require(:client_config).permit(:client_id, :authentication, :anti_csrf, :redirect_uri, :description,
                                            :access_token_duration, :access_token_audience, :refresh_token_duration,
                                            :logout_redirect_uri, :pkce, :refresh_token_path, certificates: [])
    end

    def set_client_config
      @client_config = SignIn::ClientConfig.find(params[:id])
    end

    def not_found
      render json: { error: 'Client config not found' }, status: :not_found
    end
  end
end
