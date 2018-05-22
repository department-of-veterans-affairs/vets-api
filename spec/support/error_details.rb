# frozen_string_literal: true

module ErrorDetails
  def error_details_for(response, key: 'detail')
    JSON.parse(response.body)['errors'].first[key]
  end
end
