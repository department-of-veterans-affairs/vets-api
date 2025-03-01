# frozen_string_literal: true

require 'legacy_filter_query_rewrite_middleware'

Rails.application.config.middleware.insert_before 0, LegacyFilterQueryRewriteMiddleware
