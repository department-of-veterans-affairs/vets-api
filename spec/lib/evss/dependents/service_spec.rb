# frozen_string_literal: true

require 'rails_helper'

describe EVSS::Dependents::Service do
  let(:user) { create(:evss_user) }
  let(:service) { described_class.new(user) }

  describe '#retrieve' do
    VCR.use_cassette(
      'evss/dependents/retrieve',
      record: :once
    ) do
      service.retrieve
    end
  end
end
