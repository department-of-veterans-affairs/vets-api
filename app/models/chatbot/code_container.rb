# frozen_string_literal: true

module Chatbot
  class CodeContainer < Common::RedisStore
    redis_store REDIS_CONFIG[:chatbot_code_container][:namespace]
    redis_ttl REDIS_CONFIG[:chatbot_code_container][:each_ttl]
    redis_key :code

    attribute :icn, String
    attribute :code, String

    validates(:icn, :code, presence: true)
  end
end
