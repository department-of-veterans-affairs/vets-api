module HCA
  module RateLimitedSearch
    module_function

    def truncate_ssn(ssn)
      split_ssn = ssn.split('-')
      "#{split_ssn[0]}#{split_ssn[2]}"
    end

    def combine_traits(user_attributes)
      user_attributes.to_h.except(:ssn, :middle_name).values.map(&:downcase).join
      # TODO require certain fields
    end

    def create_rate_limited_searches(user_attributes)
      RateLimitedSearch.create_or_increment_count("ssn:#{truncate_ssn(user_attributes.ssn)}")
      RateLimitedSearch.create_or_increment_count("traits:#{combine_traits(user_attributes)}")
    end
  end
end
