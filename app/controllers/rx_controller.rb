class RxController < ApplicationController
  VARX_ENFORCE_SSL = Rails.env.production?
  MHV_CONFIG = VARx::Configuration.new(
    host: ENV["MHV_HOST"],
    app_token: ENV["MHV_APP_TOKEN"],
    enforce_ssl: VARX_ENFORCE_SSL
  ).freeze

  include ActionController::Serialization
  DEFAULT_PER_PAGE = 10
  MAXIMUM_PER_PAGE = 100

  respond_to :json

  before_action :authenticate_client

  protected

  # Commenting these out for now, they will be refactored later
  # def log_error(exception)
  #   Rails.logger.error "#{exception.message}. #{exception.try(:developer_message)}."
  #   Rails.logger.error exception.backtrace.join("\n") unless exception.backtrace.nil?
  # end
  #
  # def render_error(e, status_code: 500)
  #   if e.is_a? VARx::Error::ClientResponse
  #     render json: { errors: [e.as_json] }, status: status_code
  #   else
  #     render json: { errors: [errors_hash(e, status_code)] }, status: status_code
  #   end
  # end

  def client
    @client ||= VARx::Client.new(config: MHV_CONFIG, session: { user_id: ENV["MHV_USER_ID"] })
  end

  def authenticate_client
    client.authenticate if client.session.expired?
  end

  def pagination_params
    {
      page: (params[:page].try(:to_i) || 1),
      per_page: [(params[:per_page].try(:to_i) || DEFAULT_PER_PAGE), MAXIMUM_PER_PAGE].min
    }
  end

  # TODO: These belong in ApplicationController and will use VA-API-COMMON Exceptions
  # private
  #
  # def errors_hash(e, status_code)
  #   base_json = { major: status_code, minor: "", message: e.message }
  #   return base_json unless Rails.env.development? || Rails.env.test?
  #   cause = e.cause.nil? ? {} : { message: e.cause.message, error: e.cause.backtrace }
  #   base_json.merge(developer_message: "", error: e.backtrace, cause: cause)
  # end
end
