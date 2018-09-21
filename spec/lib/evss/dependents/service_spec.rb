# frozen_string_literal: true

require 'rails_helper'

describe EVSS::Dependents::Service do
  let(:user) { create(:evss_user) }
  let(:service) { described_class.new(user) }

  describe '#retrieve' do
    it 'should get user details' do
      VCR.use_cassette(
        'evss/dependents/retrieve'
      ) do
        response = service.retrieve
        binding.pry; fail
      end
    end
  end
end
