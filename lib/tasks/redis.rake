# frozen_string_literal: true
namespace :redis do
  desc 'Flush Vets.gov User/Sessions'
  task flush_session: [:flush_session_store, :flush_users_store]

  desc 'Flush RedisStore: Session'
  task :flush_session_store do
    namespace = Session.new.redis_namespace.namespace
    Redis.current.scan_each(match: /^#{namespace}/) do |key|
      redis.del(key)
    end
  end

  desc 'Flush RedisStore: User'
  task :flush_users_store do
    namespace = User.new.redis_namespace.namespace
    Redis.current.scan_each(match: /^#{namespace}/) do |key|
      redis.del(key)
    end
  end
end
