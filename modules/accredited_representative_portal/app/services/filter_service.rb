class FilterService
  def self.handle_filter(filter_params)
    filter_params[:status] ||= 'Pending'
    filter_params[:sortField] ||= 'ar_power_of_attorney_requests.created_at'
    filter_params[:sortDirection] ||= 'desc'
    filter_params[:pageNumber] ||= 0
    filter_params[:pageSize] ||= 10

    result = QueryParamsSchema.call(filter_params)
    if result.success?
      normalized_params = result.to_h

      if normalized_params[:status].present?
        if normalized_params[:status] == "Pending"
          where_clause = "resolution.id is null"
          join_clause = ""
        else
            where_clause = "resolution.resolving_type = 'AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision' and decision.type = "
          if normalized_params[:status] == "Accepted"
            join_clause = "LEFT OUTER JOIN ar_power_of_attorney_request_decisions AS decision ON decision.id = resolution.resolving_id AND resolution.resolving_type = 'AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision'"
            where_clause += "'PowerOfAttorneyRequestAcceptance'"
          elsif normalized_params[:status] == "Declined"
            join_clause = "LEFT OUTER JOIN ar_power_of_attorney_request_decisions AS decision ON decision.id = resolution.resolving_id AND resolution.resolving_type = 'AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision'"
            where_clause += "'PowerOfAttorneyRequestDeclination'"
          end
        end
      end

      sort_field = normalized_params[:sortField]
      sort_direction = normalized_params[:sortDirection] == 'asc' ? :asc : :desc

      page_number = normalized_params[:pageNumber]
      page_size = normalized_params[:pageSize]

      poa_requests = AccreditedRepresentativePortal::PowerOfAttorneyRequest
        .joins('LEFT OUTER JOIN ar_power_of_attorney_request_resolutions AS resolution ON resolution.power_of_attorney_request_id = ar_power_of_attorney_requests.id')
        .joins(join_clause)
        .where(where_clause)
        .order(sort_field => sort_direction)
        .offset(page_number * page_size)
        .limit(page_size)
    else
      errors = result.errors.to_h
    end

    return poa_requests, errors
  end
end
