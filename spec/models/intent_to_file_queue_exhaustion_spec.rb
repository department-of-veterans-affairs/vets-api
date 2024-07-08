# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IntentToFileQueueExhaustion, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:veteran_icn) }
  end
end
