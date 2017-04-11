# frozen_string_literal: true
require 'rails_helper'
require 'mhv_ac/registration_form'

describe MHVAC::RegistrationForm do
  let(:user) { build(:user) }

  it 'can initialize a user from mvi data' do
    form = described_class.from_user(user)
  end
end
