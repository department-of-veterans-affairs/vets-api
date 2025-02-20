# frozen_string_literal: true

require 'rails_helper'
require 'lgy/service'
require 'saved_claim/coe_claim'

describe LGY::Service do
  subject { described_class.new(edipi: user.edipi, icn: user.icn) }

  let(:user) { create(:evss_user, :loa3) }
  let(:coe_claim) { create(:coe_claim) }

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
      it 'returns eligible and reference number' do
        VCR.use_cassette 'lgy/determination_eligible' do
          VCR.use_cassette 'lgy/application_not_found' do
            expect(subject.coe_status).to eq status: 'ELIGIBLE', reference_number: '16934344'
          end
        end
      end
    end

    context 'when get_determination is Unable to Determine Automatically and get_application is a 404' do
      it 'returns unable-to-determine-eligibility and reference number' do
        VCR.use_cassette 'lgy/determination_unable_to_determine' do
          VCR.use_cassette 'lgy/application_not_found' do
            expect(subject.coe_status).to eq status: 'UNABLE_TO_DETERMINE_AUTOMATICALLY', reference_number: '16934339'
          end
        end
      end
    end

    context 'when get_determination is ELIGIBLE and get_application is a 200' do
      it 'returns correct payload' do
        VCR.use_cassette 'lgy/determination_eligible' do
          VCR.use_cassette 'lgy/application_200_status_submitted' do
            expect(subject.coe_status).to eq status: 'AVAILABLE', application_create_date: 1_642_619_386_000,
                                             reference_number: '16934344'
          end
        end
      end
    end

    context 'when get_determination is NOT_ELIGIBLE' do
      it 'returns denied and reference number' do
        VCR.use_cassette 'lgy/determination_not_eligible' do
          expect(subject.coe_status).to eq status: 'DENIED', application_create_date: 1_640_016_802_000,
                                           reference_number: '16934414'
        end
      end
    end

    context 'when get_determination is Pending' do
      before { VCR.insert_cassette 'lgy/determination_pending' }

      after { VCR.eject_cassette 'lgy/determination_pending' }

      context 'and get_application is a 404' do
        before { VCR.insert_cassette 'lgy/application_not_found' }

        after { VCR.eject_cassette 'lgy/application_not_found' }

        it 'returns pending and reference number' do
          expect(subject.coe_status).to eq status: 'PENDING', reference_number: '16934414'
        end
      end

      context 'and get_application is 200 w/ status of SUBMITTED' do
        before { VCR.insert_cassette 'lgy/application_200_status_submitted' }

        after { VCR.eject_cassette 'lgy/application_200_status_submitted' }

        it 'returns pending and the application createDate and the reference number' do
          expect(subject.coe_status).to eq status: 'PENDING', application_create_date: 1_642_619_386_000,
                                           reference_number: '16934414'
        end
      end

      context 'and get_application is 200 w/ status of RETURNED' do
        before { VCR.insert_cassette 'lgy/application_200_status_returned' }

        after { VCR.eject_cassette 'lgy/application_200_status_returned' }

        it 'returns pending-upload and the application createDate and reference number' do
          expect(subject.coe_status).to eq status: 'PENDING_UPLOAD', application_create_date: 1_642_619_386_000,
                                           reference_number: '16934414'
        end
      end
    end

    context 'unexpected statuses' do
      it 'logs error to Sentry' do
        VCR.use_cassette 'lgy/determination_pending' do
          VCR.use_cassette 'lgy/application_200_status_unexpected' do
            expect_any_instance_of(LGY::Service).to receive(:log_message_to_sentry).with(
              'Unexpected COE statuses!',
              :error,
              {
                determination_status: 'PENDING',
                application_status: 'UNEXPECTED',
                get_application_status: 200
              },
              { team: 'vfs-ebenefits' }
            )
            expect(subject.coe_status).to be_nil
          end
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

  describe '#put_application' do
    context 'when submitting a valid coe claim' do
      it 'returns a valid application response' do
        VCR.use_cassette 'lgy/application_put' do
          response = subject.put_application(payload: coe_claim)
          expect(response).to include('reference_number')
          expect(response).to include('id')
          expect(response).to include('create_date')
        end
      end
    end

    context 'when submitting a valid coe claim with prior loans' do
      it 'returns a valid application response with prior loan data' do
        VCR.use_cassette 'lgy/application_put' do
          response = subject.put_application(payload: coe_claim)
          expect(response).to include('reference_number')
          expect(response).to include('status')
          expect(response['relevant_prior_loans']).not_to be_empty
        end
      end
    end

    context 'LGY returns an error' do
      it 'logs response body and headers to sentry' do
        VCR.use_cassette 'lgy/application_put_500' do
          expect_any_instance_of(LGY::Service).to receive(:log_message_to_sentry).with(
            'COE application submission failed with http status: 500',
            :error,
            { message: 'the server responded with status 500', status: 500,
              body: { 'errors' => [{ 'message' => 'Fake error message' }] } },
            { team: 'vfs-ebenefits' }
          )
          expect do
            subject.put_application(payload: coe_claim)
          end.to raise_error(Common::Client::Errors::ClientError)
        end
      end
    end
  end

  describe '#post_document' do
    context 'when uploading a document to LGY' do
      it 'returns a valid response' do
        VCR.use_cassette 'lgy/document_post' do
          document_data = {
            'documentType' => '.pdf',
            'description' => 'Statement of service',
            'contentsBase64' => Base64.encode64(File.read('spec/fixtures/files/lgy_file.pdf')),
            'fileName' => 'lgy_file.pdf'
          }

          response = subject.post_document(payload: document_data)
          expect(response.status).to eq 201
          expect(response.body).to include('id')
          expect(response.body).to include('create_date')
        end
      end
    end
  end

  describe '#get_coe_documents' do
    context 'when retrieving the document list from LGY' do
      it 'returns a document list' do
        VCR.use_cassette 'lgy/documents_list' do
          response = subject.get_coe_documents
          expect(response.status).to eq 200
          expect(response.body).to include(include('id'))
          expect(response.body).to include(include('create_date'))
          expect(response.body).to include(include('description'))
        end
      end
    end
  end

  describe '#get_document' do
    context 'when downloading an available document from LGY' do
      it 'returns the document' do
        # documents_list contains a single document with id: 23215740
        VCR.use_cassette 'lgy/documents_list' do
          # document_download returns a fake document
          VCR.use_cassette 'lgy/document_download' do
            response = subject.get_document('23215740')
            expect(response.status).to eq 200
          end
        end
      end
    end

    context 'when the document is not available' do
      it 'returns a 404 not found' do
        # documents_list contains a single document with id: 23215740
        VCR.use_cassette 'lgy/documents_list' do
          # This request will never actually be made, because documents_list
          # doesn't contain a document with id 234567890. It is at that point
          # that we raise a 404.
          VCR.use_cassette 'lgy/document_download_not_found' do
            expect { subject.get_document('234567890') }.to raise_error(Common::Exceptions::RecordNotFound)
          end
        end
      end
    end
  end
end
