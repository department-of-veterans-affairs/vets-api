# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/claims_service/claims_service_provider'

RSpec.describe ClaimsServiceProvider do
  let(:current_user) { build(:user) }

  it 'always raises an error on the ClaimsServiceProvider base module' do
    expect do
      ClaimsServiceProvider.all_claims
    end.to raise_error NotImplementedError
  end
end
