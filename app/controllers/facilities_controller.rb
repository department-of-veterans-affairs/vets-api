# frozen_string_literal: true

class FacilitiesController < ApplicationController
  skip_before_action :authenticate

  def validate_params
    if params[:bbox]
      raise ArgumentError unless params[:bbox]&.length == 4

      params[:bbox].each { |x| Float(x) }
    end
  rescue ArgumentError
    raise Common::Exceptions::InvalidFieldValue.new('bbox', params[:bbox])
  end

  private

  def render_json(serializer, obj, options={})
    if obj.class.name == 'ActiveRecord::Relation'
      return render_collection(serializer, obj, options)
    end

    render_record(serializer, obj, options)
  end
  
  def render_collection(serializer, collection, options={})
    options = meta_pagination(collection, options)
    render_record(serializer, collection, options)
  end

  def render_record(serializer, record, options={})
    render json: serializer.new(record, options)
  end

  def meta_pagination(paginated_obj, options={})
    options[:meta] = {} unless options.has_key?(:meta)
    meta_options = options[:meta].merge(generate_pagination(paginated_obj))
    options[:meta] = meta_options
    options[:links] = {} unless options.has_key?(:links)
    link_options = options[:links].merge(generate_links(paginated_obj))
    options[:links] = link_options
    options
  end

  def generate_pagination(paginated_obj)
    {
      pagination: {
        current_page: paginated_obj.current_page,
        prev_page: paginated_obj.previous_page,
        next_page: paginated_obj.next_page,
        total_pages: paginated_obj.total_pages
      }
    }
  end

  def generate_links(paginated_obj)
    links = {
      self: resource_path(
        lighthouse_params.merge(page: paginated_obj.current_page, per_page: paginated_obj.per_page)
      ),
      first: resource_path(
        lighthouse_params.merge(per_page: paginated_obj.per_page)
      ),
      prev: nil,
      next: nil,
      last: resource_path(
        lighthouse_params.merge(page: paginated_obj.total_pages, per_page: paginated_obj.per_page)
      )
    }
 
    if paginated_obj.previous_page
      links[:prev] = resource_path(
        lighthouse_params.merge(page: paginated_obj.previous_page, per_page: paginated_obj.per_page)
      )
    end

    if paginated_obj.next_page
      links[:next] = resource_path(
        lighthouse_params.merge(page: paginated_obj.next_page, per_page: paginated_obj.per_page)
      )
    end

    #Slicing the hash to fix the order
    links.slice(:self, :first, :prev, :next, :last)
  end

end
