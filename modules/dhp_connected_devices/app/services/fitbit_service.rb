# frozen_string_literal: true

require 'fitbit/client'

class FitbitService
  def get_connection_status(data)
    fitbit_client = data.fetch(:fitbit_api)
    if data[:callback_params][:code] && exchange_code_for_token({ code: data[:callback_params][:code],
                                                                  client: fitbit_client })
      'success'
    else
      'error'
    end
  end

  private

  def exchange_code_for_token(data)
    response = data.fetch(:client).get_token(data.fetch(:code))
    response.status == 200
  end
end
