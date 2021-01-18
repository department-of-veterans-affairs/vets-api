# frozen_string_literal: true

class MockOpenIdUser < OpenidUser
  redis_store REDIS_CONFIG[:openid_user_store][:namespace]
  redis_ttl REDIS_CONFIG[:openid_user_store][:each_ttl]
  redis_key :uuid
  delegate :veteran?, to: :mock_veteran_status
  %w[mock_veteran_status].each do |emis_method|
    define_method(emis_method) do
      emis_model = instance_variable_get(:"@#{emis_method}")
      return emis_model if emis_model.present?

      emis_model = "EMISRedis::#{emis_method.camelize}".constantize.for_user(self)
      instance_variable_set(:"@#{emis_method}", emis_model)
      emis_model
    end
  end
end
