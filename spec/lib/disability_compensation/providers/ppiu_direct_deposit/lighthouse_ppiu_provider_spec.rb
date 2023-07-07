# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/ppiu_direct_deposit/lighthouse_ppiu_provider'
require 'support/disability_compensation_form/shared_examples/ppiu_provider'

RSpec.describe LighthousePPIUProvider do
  let(:current_user) { build(:user, :loa3) }
  let(:provider) { LighthousePPIUProvider.new(current_user) }

  # TODO: Uncomment once Lighthouse provider is implemented in #59698
  # it_behaves_like 'ppiu direct deposit provider'

  # TODO: Remove once Lighthouse provider is implemented in #59698
  it 'throws a not implemented error' do
    expect do
      provider.get_payment_information
    end.to raise_error NotImplementedError
  end
end
