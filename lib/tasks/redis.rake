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
  task :create_sessions, [:count, :mhv_id] => [:environment] do |_, args|
    args.with_defaults(count: 50, mhv_id: nil)
    redis = Redis.current

    args[:count].to_i.times do
      uuid = SecureRandom.uuid.delete '-'
      token = SecureRandom.uuid.delete '-'
      mhv_ids = [args[:mhv_id] || %w(12210827 10894456 13408508 13492196).sample]

      session = Session.new(token: token, uuid: uuid)
      session.save

      redis.set "users:#{uuid}", {
        ":uuid": uuid,
        ":email": "vets.gov.user+#{rand(200)}@gmail.com",
        ":first_name": 'TEST',
        ":middle_name": 'T',
        ":last_name": 'USER',
        ":gender": 'F',
        ":birth_date": "1970-01-01",
        ":zip": nil,
        ":ssn": '123456789',
        ":loa": {
          ":current": 3,
          ":highest": 3
        },
        ":last_signed_in": { "^t": Time.now.utc },
        ":mhv_last_signed_in": nil
      }.to_json

      redis.set "mvi-profile-response:#{uuid}", {
        ":uuid": uuid,
        ":status": "OK",
        ":profile": {
          "^o": "MviProfile",
          "birth_date": "19700101",
          "edipi": "1005079124",
          "family_name": "USER",
          "gender": "F",
          "given_names": ["TEST", "T"],
          "icn": "1008710255V058302",
          "mhv_ids": mhv_ids,
          "ssn": "123456789",
          "suffix": nil,
          "address": nil,
          "home_phone": nil,
          "participant_id": "600062099",
        }
      }.to_json

      puts token
    end
  end
end
