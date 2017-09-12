# frozen_string_literal: true
require 'rails_helper'

describe EMISRedis::Payment, skip_emis: true do
  let(:user) { build :loa3_user }
  subject { described_class.for_user(user) }
end
