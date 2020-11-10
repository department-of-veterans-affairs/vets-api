# frozen_string_literal: true

require '/home/luke/Repositories/vets-api/app/models/openid_user'
require 'emis/mock_veteran_status'
class MockOpenidUser < OpenidUser
  redis_store REDIS_CONFIG[:openid_user_store][:namespace]
  redis_ttl REDIS_CONFIG[:openid_user_store][:each_ttl]
  redis_key :uuid
  delegate :veteran?, to: :mock_veteran_status
  %w[veteran_status military_information payment mock_veteran_status].each do |emis_method|
    define_method(emis_method) do
      emis_model = instance_variable_get(:"@#{emis_method}")
      return emis_model if emis_model.present?

      emis_model = "EMISRedis::#{emis_method.camelize}".constantize.for_user(self)
      instance_variable_set(:"@#{emis_method}", emis_model)
      emis_model
    end
  end

  def identity
    @identity ||= OpenidUserIdentity.find(uuid)
  end

  def self.build_from_identity(identity:, ttl:)
    user = new(identity.attributes)
    user.expire(ttl)
    user
  end
end
