# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/communication/service'

describe VAProfile::CommunicationService do
  subject { described_class.new(user) }
end
