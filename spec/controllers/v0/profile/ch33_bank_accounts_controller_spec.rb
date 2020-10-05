# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::Ch33BankAccountsController, type: :controller do

  let(:user) { FactoryBot.build(:ch33_dd_user) }

  before do
    sign_in_as(user)
  end

  describe '#index' do
    it 'returns the right data' do
      VCR.use_cassette('bgs/service/find_ch33_dd_eft', VCR::MATCH_EVERYTHING) do
        get(:index)
      end
      binding.pry; fail
    end
  end
end
