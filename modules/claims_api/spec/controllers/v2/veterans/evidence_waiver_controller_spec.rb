# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::V2::Veterans::EvidenceWaiverController do
  describe '#verify_if_dependent_claim!' do
    # rubocop:disable RSpec/SubjectStub
    it 'raises a 404 if there is no pctpnt_vet_id' do
      allow(subject).to receive(:set_bgs_claim!).and_return({ benefit_claim_details_dto: { ptcpnt_vet_id: nil } })

      expect do
        subject.send(:verify_if_dependent_claim!)
      end.to raise_error(Common::Exceptions::ResourceNotFound)
    end
    # rubocop:enable RSpec/SubjectStub
  end
end
