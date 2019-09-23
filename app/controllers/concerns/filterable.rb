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

  def filter_query
    @filter_query ||= begin
      q = URI.parse(request.url).query || ''
      q.split('&').select { |a| a.include?('filter') }
    end
  end

  def valid_filters?
    filter_query.map { |a| a.gsub('filter', '') }.all? { |s| s =~ /\A\[\[.+\]\[.+\]\]=.+\z/ }
  end

  def filter_params
    params.require(:filter).permit(Prescription.filterable_attributes.merge(Message.filterable_attributes))
  end
end
