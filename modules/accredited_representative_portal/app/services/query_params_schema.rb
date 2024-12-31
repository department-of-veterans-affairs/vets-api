require 'dry-schema'

QueryParamsSchema = Dry::Schema.Params do
  required(:status).filled(:string, included_in?: ['Pending', 'Accepted', 'Declined'])
  required(:sortField).filled(:string, included_in?: ['resolution.created_at', 'ar_power_of_attorney_requests.created_at'])
  required(:sortDirection).filled(:string, included_in?: ['asc', 'desc'])
  required(:pageNumber).filled(:integer, gt?: -1)
  required(:pageSize).filled(:integer, gt?: 0)
end
