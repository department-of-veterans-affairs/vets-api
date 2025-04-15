# frozen_string_literal: true

require 'common/models/base'

class VamcEhr < Common::Base
  include RedisCaching

  redis_config REDIS_CONFIG[:secure_messaging_store]

  attribute :data do
    attribute :nodeQuery do
      attribute :count, Integer
      attribute :entities, Array do
        attribute :title, String
        attribute :fieldFacilityLocatorApiId, String
        attribute :fieldRegionPage do
          attribute :entity do
            attribute :title, String
            attribute :fieldVamcEhrSystem, String
          end
        end
      end
    end
  end

end

