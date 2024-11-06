# Basically a wrapper


class CarClient
  BASE_URL = 'https://api.cars.example.com'

  def initialize
    @connection = Faraday.new(url: BASE_URL) do |faraday|
      faraday.headers['Content-Type'] = 'application/json'
      faraday.request :url_encoded
      faraday.response :logger
      faraday.adapter Faraday.default_adapter
    end
  end

  def post_car(car_params)
    response = @connection.post('/cars') do |req|
      req.body = car_params.to_json
    end
    parse_response(response)
  end

  def get_cars
    response = @connection.get('/cars')
    parse_response(response)
  end

  def get_car(id)
    response = @connection.get("/cars/#{id}")
    parse_response(response)
  end

  def put_car(id, car_params)
    response = @connection.put("/cars/#{id}") do |req|
      req.body = car_params.to_json
    end
    parse_response(response)
  end

  def delete_car(id)
    response = @connection.delete("/cars/#{id}")
    parse_response(response)
  end

  private

  # Helper method to parse JSON responses
  def parse_response(response)
    if response.success?
      JSON.parse(response.body)
    else
      { error: response.status, message: response.body }
    end
  end
end
