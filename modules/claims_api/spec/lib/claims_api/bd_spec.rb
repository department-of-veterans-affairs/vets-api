# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'

describe ClaimsApi::BD do
  subject { described_class.new }

  let(:ews) do
    create(:evidence_waiver_submission, :with_full_headers, claim_id: '60897890',
                                                            id: '43fc03ab-86df-4386-977b-4e5b87f0817f',
                                                            tracked_items: [234, 235])
  end.freeze
  let(:claim) { create(:auto_established_claim, evss_id: 600_400_688, id: '581128c6-ad08-4b1e-8b82-c3640e829fb3') }
  let(:body) { 'test body' }

  before do
    allow_any_instance_of(ClaimsApi::V2::BenefitsDocuments::Service)
      .to receive(:get_auth_token).and_return('some-value-here')
  end

  describe 'disability comp (doc_type: L122), and other attachments (doc_type: L023)' do
    let(:pdf_path) { 'modules/claims_api/spec/fixtures/21-526EZ.pdf' }

    describe '#upload' do
      it 'uploads a document to BD' do
        VCR.use_cassette('claims_api/bd/upload') do
          result = subject.upload(claim:, pdf_path:, doc_type: 'L122')
          expect(result).to be_a Hash
          expect(result[:data][:success]).to be true
        end
      end

      it 'uploads a document to BD using refactored #upload_document' do
        VCR.use_cassette('claims_api/bd/upload') do
          result = subject.upload_document(identifier: claim.evss_id, doc_type_name: 'claim', body:)
          expect(result).to be_a Hash
          expect(result[:data][:success]).to be true
        end
      end

      it 'uploads an attachment to BD for L023' do
        result = subject.send(:generate_upload_body, claim:, doc_type: 'L023', pdf_path:, action: 'post',
                                                     original_filename: 'stuff.pdf')
        js = JSON.parse(result[:parameters].read)
        expect(js['data']['docType']).to eq 'L023'
        expect(js['data']['claimId']).to eq claim.evss_id
        expect(js['data']['systemName']).to eq 'VA.gov'
        expect(js['data']['trackedItemIds']).to eq []
      end

      it 'uploads an attachment to BD for L122' do
        result = subject.send(:generate_upload_body, claim:, doc_type: 'L122', original_filename: '21-526EZ.pdf',
                                                     pdf_path:, action: 'post')
        js = JSON.parse(result[:parameters].read)
        expect(js['data']['docType']).to eq 'L122'
        expect(js['data']['claimId']).to eq claim.evss_id
        expect(js['data']['systemName']).to eq 'VA.gov'
        expect(js['data']['trackedItemIds']).to eq []
      end
    end

    describe '#search', vcr: 'claims_api/v2/claims_show' do
      let(:claim_id) { '600397218' }
      let(:file_number) { '796378782' }

      it 'locates claim documents when provided a fileNumber and claimId' do
        result = subject.search(claim_id, file_number)

        expect(result).to be_a Hash
        expect(result[:data][:documents]).to be_truthy
      end
    end

    describe '#build_body' do
      it 'builds an L122 (526) body correctly' do
        result = subject.send(:build_body, doc_type: 'L122', file_name: '21-526EZ.pdf', claim_id: claim.id)

        expected = { data: { systemName: 'VA.gov', docType: 'L122', claimId: '581128c6-ad08-4b1e-8b82-c3640e829fb3',
                             fileName: '21-526EZ.pdf', trackedItemIds: [] } }
        expect(result).to eq(expected)
      end

      it 'builds an L023 (correspondence) body correctly' do
        result = subject.send(:build_body, doc_type: 'L023', file_name: 'rx.pdf', claim_id: claim.id)

        expected = { data: { systemName: 'VA.gov', docType: 'L023', claimId: '581128c6-ad08-4b1e-8b82-c3640e829fb3',
                             fileName: 'rx.pdf', trackedItemIds: [] } }
        expect(result).to eq(expected)
      end
    end

    describe 'power of attorney submissions (doc_type: L075, L190)' do
      let(:power_of_attorney) { create(:power_of_attorney, :with_full_headers) }
      let(:poa_with_pctpnt_id_in_headers) { create(:power_of_attorney, :with_full_headers_tamara) }

      context 'when the doctype is L190' do
        let(:pdf_path) { 'modules/claims_api/spec/fixtures/21-22/signed_filled_final.pdf' }
        let(:json_body) do
          res = subject.send(:generate_upload_body, claim: power_of_attorney, pdf_path:, action: 'post',
                                                    doc_type: 'L190')
          temp_io = res[:parameters].instance_variable_get(:@io).path
          temp_io_contents = File.read(temp_io)
          JSON.parse(temp_io_contents)
        end

        it 'the systemName is Lighthouse' do
          expect(json_body['data']['systemName']).to eq('Lighthouse')
        end

        it 'the docType is L190' do
          expect(json_body['data']['docType']).to eq('L190')
        end

        it 'the fileName ends in 21-22.pdf' do
          expect(json_body['data']['fileName']).to end_with('21-22.pdf')
        end

        it 'the claimId is not present' do
          expect(json_body['data']).not_to have_key('claimId')
        end

        it 'gets the participant vet id from the headers va_eauth_pid when it is not supplied for L190' do
          poa_with_pctpnt_id_in_headers.auth_headers['va_eauth_pid']
          expect_any_instance_of(described_class).to receive(:build_body).with(
            {
              doc_type: 'L190',
              file_name: 'Tamara_Ellis_21-22.pdf',
              participant_id: '600043201',
              claim_id: nil,
              file_number: nil,
              system_name: 'Lighthouse',
              tracked_item_ids: nil
            }
          )

          subject.send(:generate_upload_body, claim: poa_with_pctpnt_id_in_headers, pdf_path:, action: 'post',
                                              doc_type: 'L190')
        end
      end

      context 'when the doctype is L075' do
        context 'when the api version is v2' do
          let(:pdf_path) { 'modules/claims_api/spec/fixtures/21-22A/signed_filled_final.pdf' }
          let(:json_body) do
            res = subject.send(:generate_upload_body, claim: power_of_attorney, pdf_path:, action: 'post',
                                                      doc_type: 'L075')
            temp_io = res[:parameters].instance_variable_get(:@io).path
            temp_io_contents = File.read(temp_io)
            JSON.parse(temp_io_contents)
          end

          it 'the systemName is Lighthouse' do
            expect(json_body['data']['systemName']).to eq('Lighthouse')
          end

          it 'the docType is L075' do
            expect(json_body['data']['docType']).to eq('L075')
          end

          it 'the fileName ends in 21-22a.pdf' do
            expect(json_body['data']['fileName']).to end_with('21-22a.pdf')
          end

          it 'the claimId is not present' do
            expect(json_body['data']).not_to have_key('claimId')
          end
        end

        context 'when the api version is v1' do
          context 'the doc type is 21-22a' do
            let(:pdf_path) { 'modules/claims_api/spec/fixtures/21-22A/signed_filled_final.pdf' }
            let(:json_body) do
              res = subject.send(:generate_upload_body, claim: power_of_attorney, pdf_path:, action: 'put',
                                                        doc_type: 'L075')
              temp_io = res[:parameters].instance_variable_get(:@io).path
              temp_io_contents = File.read(temp_io)
              JSON.parse(temp_io_contents)
            end

            it 'the fileName ends in representative.pdf' do
              expect(json_body['data']['fileName']).to end_with('_representative.pdf')
            end
          end

          context 'the doc type is 21-22' do
            let(:pdf_path) { 'modules/claims_api/spec/fixtures/21-22/signed_filled_final.pdf' }
            let(:json_body) do
              res = subject.send(:generate_upload_body, claim: power_of_attorney, pdf_path:, action: 'put',
                                                        doc_type: 'L190')
              temp_io = res[:parameters].instance_variable_get(:@io).path
              temp_io_contents = File.read(temp_io)
              JSON.parse(temp_io_contents)
            end

            it 'the fileName ends in representative.pdf' do
              expect(json_body['data']['fileName']).to end_with('_representative.pdf')
            end
          end
        end
      end
    end

    context 'when the upstream service is down' do
      let(:client) { instance_double(Faraday::Connection) }
      let(:response) { instance_double(Faraday::Response, body: 'failed to request: timeout') }

      before do
        allow(Faraday).to receive(:new).and_return(client)
        allow(client).to receive(:post).and_return(response)
      end

      it 'raises a GatewayTimeout exception' do
        expect do
          subject.upload(claim:, pdf_path:, doc_type: 'L122')
        end.to raise_error(Common::Exceptions::GatewayTimeout)
      end
    end
  end

  describe 'evidence waiver submissions (doc_type: L705)' do
    let(:pdf_path) { 'modules/claims_api/spec/fixtures/5103.pdf' }

    describe '#generate_upload_body' do
      it 'uploads an attachment to BD for L705' do
        result = subject.send(:generate_upload_body, claim: ews, doc_type: 'L705', original_filename: '5103.pdf',
                                                     pdf_path:, action: 'post')
        js = JSON.parse(result[:parameters].read)
        expect(js['data']['docType']).to eq 'L705'
        expect(js['data']['claimId']).to eq ews.claim_id
        expect(js['data']['systemName']).to eq 'VA.gov'
        expect(js['data']['trackedItemIds']).to eq [234, 235]
      end

      it 'sends only a participant id and not a file number for 5103' do
        result = subject.send(:generate_upload_body, claim: ews, doc_type: 'L705', original_filename: '5103.pdf',
                                                     pdf_path:, action: 'post', pctpnt_vet_id: '123456789')
        js = JSON.parse(result[:parameters].read)
        expect(js['data']['fileNumber']).not_to be_truthy
        expect(js['data']['fileNumber']).to be_nil
      end
    end

    describe '#build_body' do
      let(:tracked_item_ids) { ews.tracked_items }

      it 'builds an L705 (5103) body correctly' do
        result = subject.send(:build_body, doc_type: 'L705', file_name: '5103.pdf', claim_id: ews.claim_id,
                                           tracked_item_ids:)

        expected = { data: { systemName: 'VA.gov', docType: 'L705', claimId: '60897890',
                             fileName: '5103.pdf', trackedItemIds: [234, 235] } }
        expect(result).to eq(expected)
      end

      it 'builds an L705 (5103) body with all of the params correctly' do
        result = subject.send(:build_body, doc_type: 'L705', file_name: '5103.pdf', claim_id: ews.claim_id,
                                           participant_id: '60289076',
                                           file_number: '7348296', tracked_item_ids:)

        expected = { data: { systemName: 'VA.gov', docType: 'L705', claimId: '60897890',
                             fileName: '5103.pdf', trackedItemIds: [234, 235], participantId: '60289076',
                             fileNumber: '7348296' } }
        expect(result).to eq(expected)
      end
    end

    context 'when the upstream service is down' do
      let(:client) { instance_double(Faraday::Connection) }
      let(:response) { instance_double(Faraday::Response, body: 'failed to request: timeout') }
      let(:claim_id) { '600397218' }
      let(:file_number) { '796378782' }

      before do
        allow(ClaimsApi::Logger).to receive(:log)
        allow(Faraday).to receive(:new).and_return(client)
        allow(client).to receive(:post).and_return(response)
      end

      it 'returns an empty hash' do
        result = subject.search(claim_id, file_number)

        expect(result).to eq({})
      end

      it 'logs the Gateway timeout' do
        subject.search(claim_id, file_number)

        expect(ClaimsApi::Logger).to have_received(:log)
          .with('benefits_documents', { detail: "/search failure for claimId #{claim_id}, Gateway timeout" })
      end
    end
  end
end
