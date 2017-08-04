# frozen_string_literal: true
module Filterable
  extend ActiveSupport::Concern

  included do
    before_action :validate_filter_params!, only: :index
  end

  def validate_filter_params!
    if params[:filter].present?
      return true if valid_filters?
      raise Common::Exceptions::InvalidFiltersSyntax, filter_query
    end
  end

  private

  def filter_params
    params.permit(:filter)
  end

  def sort_params
    params.permit(:sort)
  end

  def filter_query
    @filter_query ||= begin
      q = URI.parse(request.url).query || ''
      q.split('&').select { |a| a.include?('filter') }
    end
  end

  def valid_filters?
    filter_query.map { |a| a.gsub('filter', '') }.all? { |s| s =~ /\A\[\[.+\]\[.+\]\]=.+\z/ }
  end
end
