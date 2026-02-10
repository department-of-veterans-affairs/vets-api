# frozen_string_literal: true

module Filterable
  extend ActiveSupport::Concern

  included do
    before_action :normalize_filter_params!, only: :index
    before_action :validate_filter_params!, only: :index
  end

  def normalize_filter_params!
    return if params[:filter].blank?

    if params[:filter].keys.any? { |k| k.include?('[') || k.include?(']') }
      normalized_filter = {}

      params[:filter].each do |key, value|
        clean_key = key.gsub(/[\[\]]/, '')

        if value.is_a?(ActionController::Parameters)
          operator = value.keys.first.gsub(/[\[\]]/, '')
          actual_value = value[value.keys.first]
          actual_value = actual_value[']'] if actual_value.is_a?(ActionController::Parameters) && actual_value.key?(']')

          normalized_filter[clean_key] = { operator => actual_value }
        else
          normalized_filter[clean_key] = value
        end
      end

      params[:filter] = ActionController::Parameters.new(normalized_filter)
    end
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
    filter_query.map { |a| a.gsub('filter', '') }.all? do |s|
      s =~ /\A\[\[.+\]\[.+\]\]=.+\z/ || # Single brackets: filter[key][subkey]=value
        s =~ /\A\[[^\]]+\]\[[^\]]+\]=.+\z/ # Double brackets: filter[[key][subkey]]=value
    end
  end

  def filter_params
    params.require(:filter).permit(Prescription.filterable_params.merge(Message.filterable_params))
  end
end
