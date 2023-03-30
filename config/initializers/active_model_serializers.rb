# frozen_string_literal: true

# This module monkey patches the pagination links defined by the json-api adapter_options
# to more closely match the specifications
module CustomPaginationLinks
  FIRST_PAGE = 1

  def as_json
    per_page = collection.try(:per_page) || collection.try(:limit_value) || collection.size
    pagination_links = pages_from.each_with_object({}) do |(key, value), hash|
      # Use the non nested syntax for pagination params
      params = query_parameters.merge(page: value, per_page:).to_query
      # Changed this to set the value to nil when no value is specified by pages_from
      hash[key] = value.present? ? "#{base_path}?#{params}" : nil
    end
    # Always include self, regardless of pagination links existing or not.
    { self: "#{base_path}?#{query_parameters.to_query}" }.merge(pagination_links)
  end

  private

  def base_path
    "#{Rails.application.config.protocol}://#{Rails.application.config.hostname}#{path_partial}"
  end

  def path_partial
    URI.parse(request_url).path
  end

  # Changed these to allow nil values, this way the keys are always present, but possibly null
  def pages_from
    # return {} if collection.total_pages <= FIRST_PAGE
    {}.tap do |pages|
      pages[:first] = FIRST_PAGE
      pages[:prev] = first_page? ? nil : collection.current_page - FIRST_PAGE
      pages[:next] = last_page? ? nil : collection.current_page + FIRST_PAGE
      pages[:last] = collection.total_pages
    end
  end

  def first_page?
    collection.current_page == FIRST_PAGE
  end

  def last_page?
    collection.current_page == collection.total_pages
  end
end

# Prepend the custom module so that it overrides those in the gem.
ActiveModelSerializers::Adapter::JsonApi::PaginationLinks.prepend CustomPaginationLinks
ActiveModelSerializers.config.adapter = :json_api
ActiveModelSerializers.config.key_transform = :underscore
