# a new model backed by an external api

module Complex
  class Car
    def initialize(attributes = {})
      @id = attributes['id']
      @make = attributes['make']
      @model = attributes['model']
      @year = attributes['year']
    end

    def self.list(params = {})
      response = client.request(method: :get, path: "cars", params: params)
      from_response(response)
    end

    def self.retrieve(id)
      response = client.request(method: :get, path: "cars/#{id}")
      from_response(response)
    end

    def self.create(params = {})
      response = client.request(method: :post, path: "cars", params: params)
      from_response(response)
    end

    def self.update(id, params = {})
      response = client.request(method: :put, path: "cars/#{id}", params: params)
      from_response(response)
    end

    def self.delete(id)
      response = client.request(method: :delete, path: "cars/#{id}")
      from_response(response)
    end

    private

    def self.client
      Complex::Client.new
    end

    # Convert response to Car objects (assuming response is an array of hashes for list)
    def self.from_response(response)
      if response.is_a?(Array)
        response.map { |car_data| new(car_data) }
      else
        new(response)
      end
    end
  end
end

# Usage

car = Complex::Car.retrieve('external_api_car_id')
car = Complex::Car.create({make: "Subaru", model: "Forester", year: "2024"})
car = Complex::Car.update('external_api_car_id', {year: "2025"})




# vets-api equivalent

## Original

def index
  response = Apps::Client.new.get_all
  render json: response.body, status: response.status
end

## Updated

def index
  apps = Directory::App.list

  if apps.any?
    render json: apps.to_json, status: :ok
  else
    render json: "something went wrong", status: :bad_request
  end
end
