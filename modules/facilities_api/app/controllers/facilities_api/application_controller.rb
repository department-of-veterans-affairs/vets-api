# frozen_string_literal: true

module FacilitiesApi
  class ApplicationController < ::ApplicationController
    service_tag 'facility-locator'
    skip_before_action :authenticate

    PAGINATED_CLASSES = [
      WillPaginate::Collection,
      ActiveRecord::Relation
    ].freeze

    private

    def render_json(serializer, page_params, obj, options = {})
      # Raise exception for empty arrays that would be paginated (e.g., empty PPMS results)
      if obj.is_a?(Array) && !obj.is_a?(WillPaginate::Collection) && obj.blank?
        raise Common::Exceptions::RecordNotFound.new('empty_response',
                                                     detail: 'No records found matching the search criteria')
      end

      if PAGINATED_CLASSES.any? { |array_class| obj.is_a?(array_class) }
        render_collection(serializer, page_params, obj, options)
      else
        render_record(serializer, obj, options)
      end
    end

    def render_collection(serializer, page_params, collection, options = {})
      options = meta_pagination(collection, page_params, options)
      render_record(serializer, collection, options)
    end

    def render_record(serializer, record, options = {})
      render json: serializer.new(record, options)
    end

    def meta_pagination(paginated_obj, page_params, options = {})
      options[:meta] = {} unless options.key?(:meta)
      meta_options = options[:meta].merge(generate_pagination(paginated_obj))
      options[:meta] = meta_options
      options[:links] = {} unless options.key?(:links)
      link_options = options[:links].merge(generate_links(paginated_obj, page_params))
      options[:links] = link_options
      options
    end

    def generate_pagination(paginated_obj)
      {
        pagination: {
          current_page: paginated_obj.current_page,
          prev_page: paginated_obj.previous_page,
          next_page: paginated_obj.next_page,
          total_pages: paginated_obj.total_pages,
          total_entries: paginated_obj.total_entries
        }
      }
    end

    def generate_previous_page_link(paginated_obj, page_params)
      if paginated_obj.previous_page
        resource_path(
          page_params.merge(page: paginated_obj.previous_page, per_page: paginated_obj.per_page)
        )
      end
    end

    def generate_next_page_link(paginated_obj, page_params)
      if paginated_obj.next_page
        resource_path(
          page_params.merge(page: paginated_obj.next_page, per_page: paginated_obj.per_page)
        )
      end
    end

    def generate_links(paginated_obj, page_params)
      page_params.delete(:facilityIds)

      links = {
        self: resource_path(
          page_params.merge(page: paginated_obj.current_page, per_page: paginated_obj.per_page)
        ),
        first: resource_path(
          page_params.merge(per_page: paginated_obj.per_page)
        ),
        prev: generate_previous_page_link(paginated_obj, page_params),
        next: generate_next_page_link(paginated_obj, page_params),
        last: resource_path(
          page_params.merge(page: paginated_obj.total_pages, per_page: paginated_obj.per_page)
        )
      }

      # Slicing the hash to fix the order
      links.slice(:self, :first, :prev, :next, :last)
    end
  end
end
