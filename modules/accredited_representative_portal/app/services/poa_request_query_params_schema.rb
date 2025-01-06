# frozen_string_literal: true

require 'dry-schema'

PoaRequestQueryParamsSchema = Dry::Schema.Params do
  required(:status).filled(:string, included_in?: %w[Pending Accepted Declined])
  required(:sortField).filled(:string,
                              included_in?: ['resolution.created_at', 'ar_power_of_attorney_requests.created_at'])
  required(:sortDirection).filled(:string, included_in?: %w[asc desc])
  required(:pageNumber).filled(:integer, gt?: 0)
  required(:pageSize).filled(:integer, gt?: 0)
end
