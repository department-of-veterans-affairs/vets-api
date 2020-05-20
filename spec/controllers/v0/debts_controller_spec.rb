# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::DebtsController, type: :controller do
  let(:user) { build(:user) }

  before do
    sign_in_as(user)
  end
end
