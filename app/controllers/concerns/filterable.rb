# frozen_string_literal: true
module Filterable
  extend ActiveSupport::Concern

  def can_filter?(as, permitted = {})
    if params[:filter].present?
      check_syntax
      check_semantics(as, permitted)
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
    raise Common::Exceptions::InvalidFiltersSyntax, filter_query unless ok
  end

  # permitted = { attribute-name => [ operator-list ...] }
  def check_semantics(as, permitted = {})
    object = as.new

    params[:filter].each_pair do |attribute, predicate|
      raise Common::Exceptions::FilterNotAllowed, attribute unless permitted.key?(attribute)

      predicate.each_pair do |op, value|
        raise Common::Exceptions::FilterNotAllowed, "#{op} for #{attribute}" unless permitted[attribute].include?(op)

        begin
          object.send(attribute + '=', value)
        rescue ArgumentError
          raise Common::Exceptions::FilterNotAllowed, "Conversion of #{value} for #{attribute}"
        end
      end
    end
  end
end
