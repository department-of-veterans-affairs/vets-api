# frozen_string_literal: true

DEFAULT_PARAMS = {
  status: 'Pending',
  sortField: 'ar_power_of_attorney_requests.created_at',
  sortDirection: 'desc',
  pageNumber: 0,
  pageSize: 10
}.freeze

class PoaRequestSearchFilterService
  def self.handle_filter(filter_params)
    result = PoaRequestQueryParamsSchema.call(DEFAULT_PARAMS.merge(filter_params))
    if result.success?
      normalized_params = result.to_h
      status = normalized_params[:status]
      sort_field = normalized_params[:sortField]
      sort_direction = normalized_params[:sortDirection]
      page_number = normalized_params[:pageNumber]
      page_size = normalized_params[:pageSize]

      poa_requests = AccreditedRepresentativePortal::PowerOfAttorneyRequest.with_status(status)
                                                                           .sorted_by(sort_field, sort_direction)
                                                                           .paginated(page_number, page_size)
    else
      errors = result.errors.messages.map do |error|
        {
          field: error.path.first,
          message: error.text
        }
      end
    end

    [poa_requests, errors]
  end
end
