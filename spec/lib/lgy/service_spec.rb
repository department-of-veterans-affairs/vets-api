# frozen_string_literal: true

require 'rails_helper'
require 'lgy/service'

describe LGY::Service do
  subject { described_class.new(edipi: user.edipi, icn: user.icn) }

  let(:user) { FactoryBot.create(:evss_user, :loa3) }

  describe '#get_determination' do
    subject { described_class.new(edipi: user.edipi, icn: user.icn).get_determination }

    context 'when response is eligible' do
      before { VCR.insert_cassette 'lgy/determination_eligible' }

      after { VCR.eject_cassette 'lgy/determination_eligible' }

      it 'response code is a 200' do
        expect(subject.status).to eq 200
      end

      it "response body['status'] is ELIGIBLE" do
        expect(subject.body['status']).to eq 'ELIGIBLE'
      end

      it 'response body has key determination_date' do
        expect(subject.body).to have_key 'determination_date'
      end
    end
  end

  describe '#get_application' do
    context 'when application is not found' do
      it 'response code is a 404' do
        VCR.use_cassette 'lgy/application_not_found' do
          expect(subject.get_application.status).to eq 404
        end
      end
    end

    context 'when application is 200 and status is RETURNED' do
      before { VCR.insert_cassette 'lgy/application_200_status_returned' }

      after { VCR.eject_cassette 'lgy/application_200_status_returned' }

      it 'response code is a 200' do
        expect(subject.get_application.status).to eq 200
      end

      it 'response body has correct keys' do
        expect(subject.get_application.body).to have_key 'status'
      end
    end
  end

  describe '#coe_status' do
    context 'when get_determination is eligible and get_application is a 404' do
      it 'returns eligible' do
        VCR.use_cassette 'lgy/determination_eligible' do
          VCR.use_cassette 'lgy/application_not_found' do
            expect(subject.coe_status).to eq status: 'eligible'
          end
        end
      end
    end

    context 'when get_determination is Unable to Determine Automatically and get_application is a 404' do
      it 'returns unable-to-determine-eligibility' do
        VCR.use_cassette 'lgy/determination_unable_to_determine' do
          VCR.use_cassette 'lgy/application_not_found' do
            expect(subject.coe_status).to eq status: 'unable-to-determine-eligibility'
          end
        end
      end
    end

    context 'when get_determination is ELIGIBLE and get_application is a 200' do
      it 'returns correct payload' do
        VCR.use_cassette 'lgy/determination_eligible' do
          VCR.use_cassette 'lgy/application_200_status_submitted' do
            expect(subject.coe_status).to eq status: 'available', application_create_date: 1_642_619_386_000
          end
        end
      end
    end

    context 'when get_determination is NOT_ELIGIBLE' do
      it 'returns ineligible' do
        VCR.use_cassette 'lgy/determination_not_eligible' do
          expect(subject.coe_status).to eq status: 'ineligible'
        end
      end
    end

    context 'when get_determination is Pending' do
      before { VCR.insert_cassette 'lgy/determination_pending' }

      after { VCR.eject_cassette 'lgy/determination_pending' }

      context 'and get_application is a 404' do
        before { VCR.insert_cassette 'lgy/application_not_found' }

        after { VCR.eject_cassette 'lgy/application_not_found' }

        it 'returns pending' do
          expect(subject.coe_status).to eq status: 'pending'
        end
      end

      context 'and get_application is 200 w/ status of SUBMITTED' do
        before { VCR.insert_cassette 'lgy/application_200_status_submitted' }

        after { VCR.eject_cassette 'lgy/application_200_status_submitted' }

        it 'returns pending and the application createDate' do
          expect(subject.coe_status).to eq status: 'pending', application_create_date: 1_642_619_386_000
        end
      end

      context 'and get_application is 200 w/ status of RETURNED' do
        before { VCR.insert_cassette 'lgy/application_200_status_returned' }

        after { VCR.eject_cassette 'lgy/application_200_status_returned' }

        it 'returns pending-upload and the application createDate' do
          expect(subject.coe_status).to eq status: 'pending-upload', application_create_date: 1_642_619_386_000
        end
      end
    end
  end

  describe '#get_coe_file' do
    context 'when coe is available' do
      it 'returns a coe pdf file' do
        VCR.use_cassette 'lgy/documents_coe_file' do
          expect(subject.get_coe_file.status).to eq 200
        end
      end
    end

    context 'when coe is not available' do
      it 'returns a 404 not found' do
        VCR.use_cassette 'lgy/documents_coe_file_not_found' do
          expect(subject.get_coe_file.status).to eq 404
        end
      end
    end
  end
end
