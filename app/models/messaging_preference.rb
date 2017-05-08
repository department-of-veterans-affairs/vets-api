# frozen_string_literal: true
require 'common/models/base'
# Secure Messaging Notification Preference Model
class MessagingPreference < Common::Base
  FREQUENCY_UPDATE_MAP = {
    "none" => 0,
    "each_message" => 1,
    "daily" => 2
  }
 
  FREQUENCY_GET_MAP = {
    "None" => "none",
    "Each message" => "each_message",
    "Once daily" => "daily"
  }
  
  attribute :email_address, String
  attribute :frequency, String
end
