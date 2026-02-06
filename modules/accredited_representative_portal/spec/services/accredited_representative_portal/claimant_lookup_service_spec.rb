# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::ClaimantLookupService do
  describe '#get_icn' do
    let(:mpi_service) { instance_double(MPI::Service) }

    context 'params are missing' do
      it 'raises BadRequest' do
        expect do
          described_class.get_icn(nil, 'last_name', '111-22-3333', '01-29-1978')
        end.to raise_error(ActionController::BadRequest)
      end
    end

    context 'valid params' do
      it 'forwards params to MPI find_profile_by_attributes' do
        allow(MPI::Service).to receive(:new).and_return mpi_service
        expect(mpi_service).to receive(:find_profile_by_attributes).with(
          first_name: 'Jane',
          last_name: 'Doe',
          ssn: '111665544',
          birth_date: '1963-11-22'
        ).and_return(OpenStruct.new(profile: OpenStruct.new(icn: '1234567890V123456')))
        described_class.get_icn('Jane', 'Doe', '111-66-5544', '1963-11-22')
      end
    end

    context 'profile not found' do
      it 'raises RecordNotFound' do
        allow(MPI::Service).to receive(:new).and_return mpi_service
        allow(mpi_service).to receive(:find_profile_by_attributes).and_return(
          OpenStruct.new(profile: nil)
        )
        expect do
          described_class.get_icn('Jane', 'Doe', '111-66-5544', '1963-11-22')
        end.to raise_error(Common::Exceptions::RecordNotFound)
      end
    end
  end
end
