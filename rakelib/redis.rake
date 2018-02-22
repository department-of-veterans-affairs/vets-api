# frozen_string_literal: true

require 'emis/responses/response'
require 'emis/responses/get_veteran_status_response'

namespace :redis do
  desc 'Flush Vets.gov User/Sessions'
  task flush_session: %i[flush_session_store flush_users_store]

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
  task :create_sessions, %i[count mhv_id] => [:environment] do |_, args|
    args.with_defaults(count: 50, mhv_id: nil)
    redis = Redis.current

    args[:count].to_i.times do
      uuid = SecureRandom.uuid.delete '-'
      token = SecureRandom.uuid.delete '-'
      mhv_ids = [args[:mhv_id] || %w[12210827 10894456 13408508 13492196].sample]

      session = Session.new(token: token, uuid: uuid)
      session.save

      redis.set "users:#{uuid}", {
        ":uuid": uuid,
        ":email": "vets.gov.user+#{rand(200)}@gmail.com",
        ":first_name": 'TEST',
        ":middle_name": 'T',
        ":last_name": 'USER',
        ":gender": 'F',
        ":birth_date": '1970-01-01',
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
        ":status": 'OK',
        ":profile": {
          "^o": 'MVI::Models::MviProfile',
          "birth_date": '19700101',
          "edipi": '1005079124',
          "family_name": 'USER',
          "gender": 'F',
          "given_names": %w[TEST T],
          "icn": '1008710255V058302',
          "mhv_ids": mhv_ids,
          "ssn": '123456789',
          "suffix": nil,
          "address": {
            "^o": 'MVI::Models::MviProfileAddress',
            "street": '123 Fake Street',
            "city": 'Springfield',
            "state": 'OR',
            "postal_code": '99999',
            "country": 'USA'
          },
          "home_phone": nil,
          "participant_id": '600062099'
        }
      }.to_json

      puts token
    end
  end

  namespace :audit do
    desc 'Audit MHV/MVI User Attributes'
    task mvi: :environment do
      count = 0
      mhv_users = 0
      vha_patients = 0
      mhv_non_patient = 0
      patient_non_mhv = 0
      addressees = 0

      namespace = 'mvi-profile-response'
      redis = Redis.current
      redis.scan_each(match: "#{namespace}:*") do |key|
        begin
          resp = Oj.load(redis.get(key))[:response]
          count += 1
          mhvu = resp.profile.mhv_ids.present?
          patient = patient?(resp.profile.vha_facility_ids)
          mhv_users += 1 if mhvu
          vha_patients += 1 if patient
          mhv_non_patient += 1 if mhvu && !patient
          patient_non_mhv += 1 if patient && !mhvu
          addressees += 1 if addressee?(resp.profile.address)
        rescue
          puts "Couldn't parse #{key}"
        end
      end

      puts "Total cached users: #{count}"
      puts "Users with MHV correlation ID: #{mhv_users}"
      puts "Users who are VA patients: #{vha_patients}"
      puts "VA patients with no MHV ID: #{patient_non_mhv}"
      puts "MHV ID holders who are not patients: #{mhv_non_patient}"
      puts "Users with baseline address fields: #{addressees}"
    end

    desc 'Audit User LOA'
    task loa: :environment do
      count = 0
      loa1 = 0
      loa3 = 0

      namespace = 'users'
      redis = Redis.current
      redis.scan_each(match: "#{namespace}:*") do |key|
        begin
          u = Oj.load(redis.get(key))
          count += 1
          loa = u[:loa][:highest]
          if loa == 3
            loa3 += 1
          elsif loa == 1
            loa1 += 1
          end
        rescue
          puts "Couldn't parse #{key}"
        end
      end

      puts "Total logged-in users: #{count}"
      puts "Highest LOA3: #{loa3}"
      puts "Highest LOA1: #{loa1}"
    end

    desc 'Audit Veteran Status'
    task emis: :environment do
      count = 0
      veteran = 0

      namespace = 'veteran-status-response'
      redis = Redis.current
      redis.scan_each(match: "#{namespace}:*") do |key|
        begin
          count += 1
          resp = Oj.load(redis.get(key))[:response]
          veteran += 1 if any_veteran_indicator?(resp.items.first)
        rescue
          puts "Couldn't parse #{key}"
        end
      end

      puts "Total cached EMIS responses: #{count}"
      puts "Veterans: #{veteran}"
    end
  end
end

def any_veteran_indicator?(item)
  item&.post911_deployment_indicator == 'Y' ||
    item&.post911_combat_indicator == 'Y' ||
    item&.pre911_deployment_indicator == 'Y'
end

def patient?(vha_ids)
  vha_ids.to_a.any? { |id| id.to_i.between?(358, 758) }
end

def addressee?(addr)
  return false if addr.blank?
  return false if addr.country.blank?
  return false if addr.state.blank?
  true
end
