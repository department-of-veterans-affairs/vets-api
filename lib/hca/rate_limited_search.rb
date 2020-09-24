# frozen_string_literal: true

module HCA
  module RateLimitedSearch
    module_function

    def truncate_ssn(ssn)
      "#{ssn[0..2]}#{ssn[5..8]}"
    end

    def combine_traits(user_attributes)
      user_attributes.to_h.except(:ssn, :middle_name).values.map(&:downcase).join
    end

    def create_rate_limited_searches(user_attributes)
      ::RateLimitedSearch.create_or_increment_count("ssn:#{truncate_ssn(user_attributes.ssn)}")
      ::RateLimitedSearch.create_or_increment_count("traits:#{combine_traits(user_attributes)}")
    end
  end
end
