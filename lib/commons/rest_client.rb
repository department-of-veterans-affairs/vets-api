module Commons
  class RestClient < Base

    def default_request_types
      %i[get put post delete]
    end

    def default_request_headers
      {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'User-Agent' => 'Vets.gov Agent'
      }
    end

  end
end
