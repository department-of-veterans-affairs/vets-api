# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/ppiu_direct_deposit/ppiu_provider'

RSpec.describe PPIUProvider do
  let(:current_user) { build(:user) }

  it 'always raises an error on the PPIUProvider base module - get_payment_information' do
    expect do
      subject.get_payment_information
    end.to raise_error NotImplementedError
  end
end
