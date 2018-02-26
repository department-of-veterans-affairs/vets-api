# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserIdentity, type: :model do
  let(:user_identity) { build :user_identity }

  it_behaves_like 'a redis store with a maximum lifetime' do
    subject { described_class.new(user_identity) }
  end
end
