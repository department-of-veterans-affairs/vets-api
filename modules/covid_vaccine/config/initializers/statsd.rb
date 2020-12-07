# frozen_string_literal: true

vetext_endpoints = %w[put_vaccine_registry]

vetext_endpoints.each do |endpoint|
  StatsD.increment("api.vetext.#{endpoint}.total", 0)
  StatsD.increment("api.vetext.#{endpoint}.fail", 0)
end
