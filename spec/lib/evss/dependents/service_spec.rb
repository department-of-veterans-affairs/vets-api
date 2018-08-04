# frozen_string_literal: true

require 'rails_helper'

describe EVSS::Dependents::Service do
  let(:user) { build(:evss_user) }
  subject { described_class.new(user) }

  it 'f' do
    binding.pry; fail
  end
end
