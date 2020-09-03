# frozen_string_literal: true

require 'rails_helper'

describe IHub::Appointments::Service do
  subject { described_class.new(user) }

  let(:user) { build(:user, :loa3) }

  describe '#appointments' do
    context 'when successful' do
      before do
        allow_any_instance_of(User).to receive(:icn).and_return('1234')
      end

      it 'returns a status of 200' do
        VCR.use_cassette('ihub/appointments/success', VCR::MATCH_EVERYTHING) do
          response = subject.appointments

          expect(response).to be_ok
        end
      end

      it 'returns an array of appointment data' do
        VCR.use_cassette('ihub/appointments/success', VCR::MATCH_EVERYTHING) do
          response       = subject.appointments
          appointment    = response.appointments&.first
          facility       = appointment.facility_name
          valid_facility = 'CHEYENNE VAMC'

          expect(facility).to eq valid_facility
        end
      end
    end

    context 'when user does not have an ICN' do
      before do
        allow_any_instance_of(User).to receive(:icn).and_return(nil)
      end

      it 'raises an exception', :aggregate_failures do
        expect { subject.appointments }.to raise_error do |e|
          expect(e).to be_a(Common::Exceptions::BackendServiceException)
          expect(e.status_code).to eq(502)
          expect(e.original_body).to eq 'User has no ICN'
          expect(e.errors.first.code).to eq('IHUB_102')
        end
      end
    end

    context 'when iHub returns error_occurred: true' do
      before do
        allow_any_instance_of(User).to receive(:icn).and_return('1234')
      end

      it 'raises an exception', :aggregate_failures do
        VCR.use_cassette('ihub/appointments/error_occurred', VCR::MATCH_EVERYTHING) do
          expect { subject.appointments }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(400)
            expect(e.original_body['error_message']).to be_present
            expect(e.original_body['debug_info']).to be_present
            expect(e.errors.first.code).to eq('IHUB_101')
          end
        end
      end
    end
  end
end
