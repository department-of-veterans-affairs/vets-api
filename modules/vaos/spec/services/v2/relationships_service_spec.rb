# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::RelationshipsService do
  subject { described_class.new(user) }

  let(:user) { build(:user, :vaos) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  context 'when the upstream server returns a 500' do
    it 'raises a backend exception' do
      VCR.use_cassette('vaos/v2/relationships/get_relationships_500',
                       match_requests_on: %i[method path query]) do
        expect { subject.get_patient_relationships('primaryCare', '100') }.to raise_error(
          Common::Exceptions::BackendServiceException
        )
      end
    end
  end
end
