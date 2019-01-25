class MviSsnSearch < Common::RedisStore
  redis_store(name.underscore)
  # TODO change to 24 hours
  redis_ttl(86_400)
  redis_key(:truncated_ssn)

  attr_accessor(:truncated_ssn)

  attribute(:count, Integer)

  def self.truncate_ssn(ssn)
    split_ssn = ssn.split('-')
    "#{split_ssn[0]}#{split_ssn[2]}"
  end
end
