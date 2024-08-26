# frozen_string_literal: true

module AskVAApi
  class ApplicationController < ::ApplicationController
    service_tag 'ask-va'

    private

    def handle_exceptions
      yield
    rescue ErrorHandler::ServiceError, Crm::ErrorHandler::ServiceError => e
      log_and_render_error('service_error', e, :unprocessable_entity)
    rescue => e
      log_and_render_error('unexpected_error', e, :internal_server_error)
    end

    def log_and_render_error(action, exception, status)
      log_error(action, exception)
      render json: { error: exception.message }, status:
    end

    def log_error(action, exception)
      LogService.new.call(action) do |span|
        span.set_tag('error', true)
        span.set_tag('error.msg', exception.message)
      end
      Rails.logger.error("Error during #{action}: #{exception.message}")
    end

    def pagination_meta(page, per_page, data)
      total_entries = data.size
      total_pages = total_entries.zero? ? 1 : (total_entries / per_page.to_f).ceil
      {
        pagination: {
          current_page: page,
          per_page:,
          total_pages:,
          total_entries:
        }
      }
    end

    def meta_pagination(paginated_obj, page_params, options = {})
      pagination_info = extract_pagination_info(paginated_obj)

      options[:meta] = options.fetch(:meta, {}).merge(generate_pagination(pagination_info))
      options[:links] = options.fetch(:links, {}).merge(generate_links(pagination_info, page_params))
      options
    end

    def extract_pagination_info(paginated_obj)
      {
        current_page: paginated_obj.current_page,
        prev_page: paginated_obj.previous_page,
        next_page: paginated_obj.next_page,
        total_pages: paginated_obj.total_pages,
        total_entries: paginated_obj.total_entries,
        per_page: paginated_obj.per_page
      }
    end

    def generate_pagination(pagination_info)
      {
        pagination: {
          current_page: pagination_info[:current_page],
          prev_page: pagination_info[:prev_page],
          next_page: pagination_info[:next_page],
          total_pages: pagination_info[:total_pages],
          total_entries: pagination_info[:total_entries]
        }
      }
    end

    def generate_page_link(page, per_page, page_params)
      return nil unless page

      resource_path(page_params.merge(page:, per_page:))
    end

    def generate_links(pagination_info, page_params)
      {
        self: resource_path(page_params.merge(page: pagination_info[:current_page],
                                              per_page: pagination_info[:per_page])),
        first: resource_path(page_params.merge(page: 1, per_page: pagination_info[:per_page])),
        prev: generate_page_link(pagination_info[:prev_page], pagination_info[:per_page], page_params),
        next: generate_page_link(pagination_info[:next_page], pagination_info[:per_page], page_params),
        last: resource_path(page_params.merge(page: pagination_info[:total_pages],
                                              per_page: pagination_info[:per_page]))
      }
    end
  end
end
