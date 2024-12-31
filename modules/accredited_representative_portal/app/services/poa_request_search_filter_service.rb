# frozen_string_literal: true

class PoaRequestSearchFilterService
  DEFAULT_PARAMS = {
    status: 'Pending',
    sortField: 'ar_power_of_attorney_requests.created_at',
    sortDirection: 'desc',
    pageNumber: 1,
    pageSize: 10
  }.freeze

  attr_reader :result

  def initialize(filter_params)
    @result = PoaRequestQueryParamsSchema.call(DEFAULT_PARAMS.merge(filter_params))
  end

  def handle_filter
    if result.success?
      poa_requests = AccreditedRepresentativePortal::PowerOfAttorneyRequest
                     .with_status(status)
                     .sorted_by(sort_field, sort_direction)
                     .page(page_number)
                     .per_page(page_size)

      [poa_requests, []]
    else
      errors = result.errors.messages.map do |error|
        {
          field: error.path.first,
          message: error.text
        }
      end
      [nil, errors]
    end
  end

  private

  def status
    result.to_h[:status]
  end

  def sort_field
    result.to_h[:sortField]
  end

  def sort_direction
    result.to_h[:sortDirection]
  end

  def page_number
    result.to_h[:pageNumber]
  end

  def page_size
    result.to_h[:pageSize]
  end
end
