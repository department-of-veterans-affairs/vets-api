# frozen_string_literal: true

require './rakelib/support/sessions_serializer.rb'

class SessionsArgSerializer < SessionsSerializer
  MHV_IDS = %w[12210827 10894456 13408508 13492196].freeze

  def initialize(args)
    super
    args.with_defaults(count: 50, mhv_id: nil)
    count = args[:count].to_i
    mhv_id = args[:mhv_id]
    @uids = (0..[count, 200].max).to_a.shuffle.take(count)
    count.times { add(mhv_id) }
  end

  private

  def add(mhv_id = nil)
    uuid = save_session
    @mhv_ids = [mhv_id || MHV_IDS.sample]
    redis_set(uuid, user_data(uuid), mvi_profile_data(uuid), identity_data(uuid))
  end

  def user_data(uuid)
    {
      ":uuid": uuid,
      ":last_signed_in": { "^t": Time.now.utc },
      ":mhv_last_signed_in": nil
    }
  end

  # rubocop:disable Metrics/MethodLength
  def mvi_profile_data(uuid)
    {
      ":uuid": uuid,
      ":response": {
        "^o": 'MVI::Responses::FindProfileResponse',
        ":status": 'OK',
        ":profile": {
          "^o": 'MVI::Models::MviProfile',
          "given_names": %w[TEST T],
          "family_name": 'USER',
          "suffix": nil,
          "gender": 'F',
          "birth_date": '19700101',
          "ssn": '123456789',
          "address": {
            "^o": 'MVI::Models::MviProfileAddress',
            "street": '123 Fake Street',
            "city": 'Springfield',
            "state": 'OR',
            "postal_code": '99999',
            "country": 'USA'
          },
          "home_phone": nil,
          "icn": '1008710255V058302',
          "mhv_ids": @mhv_ids,
          "edipi": '1005079124',
          "participant_id": '600062099',
          "vha_facility_ids": %w[984 992 987 983 200ESR 556 668 200MHS],
          "birls_id": '796104437'
        }
      }
    }
  end
  # rubocop:enable Metrics/MethodLength

  def identity_data(uuid)
    {
      ":uuid": uuid,
      ":email": "vets.gov.user+#{@uids.pop}@gmail.com",
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
      ":multifactor": true,
      ":authn_context": nil,
      ":mhv_icn": nil,
      ":mhv_correlation_id": @mhv_ids.first
    }
  end
end
