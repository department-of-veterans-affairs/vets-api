# frozen_string_literal: true

class LegacyFilterQueryRewriteMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    env['QUERY_STRING'] = rewrite_legacy_filter_query(env['QUERY_STRING']) if env['QUERY_STRING']
    @app.call(env)
  end

  private

  # Rewrites query parameters from legacy syntax to RFC‑compliant syntax.
  #
  # For example, converts:
  #   filter[[disp_status][eq]]=Active,Expired
  # into:
  #   filter[disp_status][eq]=Active,Expired
  #
  # For more info see: https://github.com/rack/rack/blob/main/UPGRADE-GUIDE.md#invalid-nested-query-parsing-syntax
  def rewrite_legacy_filter_query(query)
    query.gsub(/filter\[\[([^\]]+)\]\[([^\]]+)\]\]=/) do
      "filter[#{::Regexp.last_match(1)}][#{::Regexp.last_match(2)}]="
    end
  end
end
