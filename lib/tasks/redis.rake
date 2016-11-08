# frozen_string_literal: true
namespace :redis do
  desc 'Flush Vets.gov User/Sessions'
  task flush_session: [:flush_session_store, :flush_users_store]

  desc 'Flush RedisStore: Session'
  task flush_session_store: :environment do
    namespace = Session.new.redis_namespace.namespace
    redis = Redis.current
    redis.scan_each(match: "#{namespace}:*") do |key|
      redis.del(key)
    end
  end

  desc 'Flush RedisStore: User'
  task flush_users_store: :environment do
    namespace = User.new.redis_namespace.namespace
    redis = Redis.current
    redis.scan_each(match: "#{namespace}:*") do |key|
      redis.del(key)
    end
  end

  desc 'Create test sessions'
  task :create_sessions, [:count] => [:environment] do |_, args|
    args.with_defaults(count: 50)
    redis = Redis.current

    args[:count].to_i.times do
      uuid = SecureRandom.uuid.delete '-'
      token = SecureRandom.uuid.delete '-'

      redis.set "vets-api-session:#{token}", {
        ":uuid": uuid,
        ":token": token
      }.to_json

      redis.set "mvi-data:#{uuid}", {
        ":uuid": uuid,
        ":email": 'vets.gov.user+134@gmail.com',
        ":first_name": 'TEST',
        ":middle_name": 'T',
        ":last_name": 'USER',
        ":gender": 'M',
        ":birth_date": {
          "^t": Time.now.utc
        },
        ":zip": nil,
        ":ssn": '123456789',
        ":loa": {
          ":current": 3,
          ":highest": 3
        },
        ":last_signed_in": {
          "^t": Time.now.utc
        },
        ":edipi": nil,
        ":participant_id": '600017293',
        ":mhv_id": nil,
        ":icn": '1008702225V536415',
        ":mvi": {
          "^o": 'ActiveSupport::HashWithIndifferentAccess',
          "self": {
            "birth_date": '19840101',
            "edipi": nil,
            "family_name": 'USER',
            "gender": 'M',
            "given_names": ['TEST'],
            "icn": '1008702225V536415^NI^200M^USVHA^P',
            "mhv_id": nil,
            "vba_corp_id": '600017293^PI^200CORP^USVBA^A',
            "ssn": '123456789',
            "status": 'OK'
          }
        },
        ":mhv_last_signed_in": nil
      }.to_json

      puts token
    end
  end
end
