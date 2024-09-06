class Clients::Chip::Client < Clients::Rest
  STATSD_KEY_PREFIX = 'api.chip'

  def get_demographics(params:)
    with_monitoring_and_error_handling do
      connection.get("/actions/authenticated-demographics", params, request_headers)
    end
  end

  def update_demographics(params:)
    with_monitoring_and_error_handling do
      connection.post("/actions/authenticated-demographics", params, request_headers)
    end
  end

  def post_patient_check_in(params:)
    with_monitoring_and_error_handling do
      connection.post("/actions/authenticated-checkin", params, request_headers)
    end
  rescue => e
    handle_error(e)
  end

  private

  def service_name
    'Chip'
  end

  def connection
    @connection ||= Common::Connection.configure(connection_options) do |conn|
      conn.use :breakers
      conn.request :json
      conn.response :chip_error
      conn.response :betamocks if settings.mock
      conn.adapter Faraday.default_adapter
    end
  end

  def connection_options
    {
      allowed_request_types: %i[get put post delete].freeze
      base_url: "#{Settings.chip.url}/#{Settings.chip.base_path}",
      timeouts: { read: 15, open: 15 },
      service_name:,
    }
  end

  def request_headers
    {
      'Content-Type' => 'application/json',
      'x-apigw-api-id' => config.api_gtwy_id,
      'Authorization' => "Bearer #{token}"
    }
  end

  def token
    @token ||= begin
      token = redis_client.get
      if token.present?
        token
      else
        with_monitoring do
          resp = call(:post, "/token", {}, token_headers)
        end

        Oj.load(resp.body)&.fetch('token').tap do |jwt_token|
          redis_client.save(token: jwt_token)
        end
      end
    end
  end

  def token_headers
    {
      'x-apigw-api-id' => config.api_gtwy_id,
      'Authorization' => "Basic #{ase64.encode64("#{username}:#{password}")}"
    }
  end

  def handle_error(error)
    case error
    when Common::Client::Errors::ClientError
      save_error_details(error)
      raise_backend_exception('APPS_502', self.class, error)
    else
      raise error
    end
  end
end
