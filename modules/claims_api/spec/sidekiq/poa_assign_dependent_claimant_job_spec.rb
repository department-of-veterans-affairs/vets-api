# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::PoaAssignDependentClaimantJob, type: :job do
  describe '#perform' do
    it 'calls assign_poa_to_dependent! on the dependent_claimant_poa_assignment_service' do
      dependent_claimant_poa_assignment_service = ClaimsApi::DependentClaimantPoaAssignmentService.new
      expect(dependent_claimant_poa_assignment_service).to receive(:assign_poa_to_dependent!)

      described_class.new.perform(dependent_claimant_poa_assignment_service)
    end
  end
end
