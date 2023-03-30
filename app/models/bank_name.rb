# frozen_string_literal: true

require 'common/models/concerns/cache_aside'

class BankName < Common::RedisStore
  redis_store REDIS_CONFIG[:bank_name][:namespace]
  redis_ttl REDIS_CONFIG[:bank_name][:each_ttl]
  redis_key :routing_number

  attribute :bank_name, String
  attribute :routing_number, String

  validates(:routing_number, :bank_name, presence: true)

  def self.get_bank_name(user, routing_number)
    return if routing_number.blank? || routing_number == BGS::Service::EMPTY_ROUTING_NUMBER

    bank_name = find(routing_number)

    if bank_name.blank?
      bank_name = new(routing_number:)
      bank_name.bank_name = BGS::Service.new(user).find_bank_name_by_routng_trnsit_nbr(routing_number)
      bank_name.save!
    end

    bank_name.bank_name
  end
end
