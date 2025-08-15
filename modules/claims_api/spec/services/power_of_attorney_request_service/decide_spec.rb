# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::Decide do
  subject { ClaimsApi::PowerOfAttorneyRequestService::Decide.new }

  context '#validate_decide_representative_params!' do
    let(:decision) { 'ACCEPTED' }
    let(:representative_id) { '456' }
    let(:poa_code) { '123' }

    describe 'validating the params' do
      it 'raises ResourceNotFound error with descriptive message' do
        expect do
          subject.validate_decide_representative_params!(poa_code, representative_id)
        end.to raise_error(ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound)
      end
    end

    context 'registration number and POA code combination belong to a representative' do
      let!(:rep) { create(:representative, representative_id: '456', poa_codes: ['123']) }

      it 'does not raise an error' do
        expect do
          subject.validate_decide_representative_params!(poa_code, representative_id)
        end.not_to raise_error
      end
    end
  end
end
