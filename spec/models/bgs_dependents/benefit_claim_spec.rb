# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::BenefitClaim do
  describe '#create_params_for_686c' do
    it 'creates params for submission to BGS for 686c' do
      described_class.new
    end
  end
end
