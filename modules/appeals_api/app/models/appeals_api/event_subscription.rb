# frozen_string_literal: true

# == Schema Information
#
# Table name: event_subscriptions
#
#  id         :integer          not null, primary key
#  callback   :string
#  topic      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_event_subscriptions_on_topic_and_callback  (topic,callback) UNIQUE
#

class AppealsApi::EventSubscription < ApplicationRecord
  def topic
    self[:topic].to_sym
  end

  def callback
    self[:callback].constantize
  end
end
