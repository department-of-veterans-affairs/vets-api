# frozen_string_literal: true

module JsonApiPaginationLinks
  extend ActiveSupport::Concern

  private

  def pagination_links(collection)
    total_size = collection.try(:size) || collection.data.size
    per_page = pagination_params[:per_page].try(:to_i) || total_size
    current_page = pagination_params[:page].try(:to_i) || 1
    total_pages = (total_size.to_f / per_page).ceil

    {
      self: build_page_url(current_page, per_page),
      first: build_page_url(1, per_page),
      prev: prev_link(current_page, per_page),
      next: next_link(current_page, per_page, total_pages),
      last: build_page_url(total_pages, per_page)
    }
  end

  def prev_link(current_page, per_page)
    return nil if current_page <= 1

    build_page_url(current_page - 1, per_page)
  end

  def next_link(current_page, per_page, total_pages)
    return nil if current_page >= total_pages

    build_page_url(current_page + 1, per_page)
  end

  def build_page_url(page_number, per_page)
    url_params = {
      page: page_number,
      per_page:,
      query_parameters: request.query_parameters
    }
    path_partial = URI.parse(request.original_url).path
    url = "#{base_path}#{path_partial}?#{url_params.to_query}"
    URI.parse(url).to_s
  end

  def base_path
    "#{Rails.application.config.protocol}://#{Rails.application.config.hostname}"
  end
end
