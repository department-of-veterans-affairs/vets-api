# frozen_string_literal: true
module Filterable
  extend ActiveSupport::Concern

  def can_filter?(permitted = {})
    if params[:filter].present?
      check_syntax
      check_semantics(permitted)
      true
    else
      false
    end
  end

  def filter_query
    q = URI.parse(request.url).query || ''
    @query ||= q.split('&').select { |a| a.include?('filter') }
  end

  def check_syntax
    ok = filter_query.map { |a| a.gsub('filter', '') }.all? { |s| s =~ /\A\[\[.+\]\[.+\]\]=.+\z/ }
    raise Common::Exceptions::InvalidFiltersSyntax, get_filter_query unless ok
  end

  # permitted = { attribute-name: { operations: [...], types: [...] } }
  def check_semantics(permitted = {})
    params[:filter].each_pair do |attribute, predicate|
      raise Common::Exceptions::FilterNotAllowed, attribute.to_s unless permitted.key?(attribute)

      predicate.each_pair do |op, value|
        unless permitted[attribute][operations].include?(op)
          raise Common::Exceptions::FilterNotAllowed, "#{op} for #{attribute}"
        end

        unless permitted[attribute][types].any? { |type| value is_a? type }
          raise Common::Exceptions::FilterNotAllowed, "#{value.class} for #{attribute}"
        end
      end
    end
  end
end
