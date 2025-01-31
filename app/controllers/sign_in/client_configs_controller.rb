# frozen_string_literal: true

module SignIn
  class ClientConfigsController < SignIn::ServiceAccountApplicationController
    service_tag 'identity'
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
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
        render json: { errors: client_config.errors }, status: :unprocessable_entity
      end
    end

    def update
      if @client_config.update(client_config_params)
        render json: @client_config, status: :ok
      else
        render json: { errors: @client_config.errors }, status: :unprocessable_entity
      end
    end

    def destroy
      if @client_config.destroy
        head :no_content
      else
        render json: { errors: @client_config.errors }, status: :unprocessable_entity
      end
    end

    private

    def client_config_params
      params.require(:client_config).permit(:client_id, :authentication, :redirect_uri, :refresh_token_duration,
                                            :access_token_duration, :access_token_audience, :logout_redirect_uri,
                                            :pkce, :terms_of_use_url, :enforced_terms, :shared_sessions, :anti_csrf,
                                            :description, :json_api_compatibility, certificates: [],
                                                                                   access_token_attributes: [],
                                                                                   service_levels: [],
                                                                                   credential_service_providers: [])
    end

    def set_client_config
      @client_config = SignIn::ClientConfig.find_by!(client_id: params[:client_id])
    end

    def not_found
      render json: { errors: { client_config: ['not found'] } }, status: :not_found
    end
  end
end
