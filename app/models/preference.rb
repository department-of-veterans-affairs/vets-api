# frozen_string_literal: true

require 'common/models/concerns/active_record_cache_aside'

# Class to represent a given set of Preference choices
# @see https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Data/Databases/Vets.gov/Preferences%20Schema%20Design.md#the-winning-preferences-table-design
#
class Preference < ActiveRecord::Base
  include Common::ActiveRecordCacheAside

  # Required for configuring mixed in ActiveRecordCacheAside module.
  # Redis settings for ttl and namespacing reside in config/redis.yml
  #
  has_many :user_preferences, dependent: :destroy
  has_many :preference_choices, dependent: :destroy

  validates :code,  presence: true, uniqueness: true
  validates :title, presence: true

  alias choices preference_choices

  redis_store REDIS_CONFIG['preferences']['namespace']
  redis_ttl REDIS_CONFIG['preferences']['each_ttl']

  def cache?
    persisted?
  end

  def to_param
    code
  end
end
