# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/debt_letter_downloader'
require Rails.root.join('modules', 'claims_api', 'spec', 'support', 'fake_vbms.rb')

vcr_options = {
  cassette_name: 'debts/person_data_and_letters',
  match_requests_on: %i[path query]
}

RSpec.describe DebtManagementCenter::DebtLetterDownloader, vcr: vcr_options do
  subject { described_class.new(user) }

  let(:file_number) { '796043735' }
  let(:user) { build(:user, :loa3, ssn: file_number) }
  let(:vbms_client) { FakeVBMS.new }
  let(:good_document_id) { '{93631483-E9F9-44AA-BB55-3552376400D8}' }
  let(:bad_document_id) { '{abc}' }

  def stub_vbms_client_request(request_name, args, return_val)
    request_double = double
    return_val.map { |letter| letter.upload_date = Date.parse(letter.upload_date) }
    expect(
      "VBMS::Requests::#{request_name}".constantize
    ).to receive(:new).at_most(:twice).with(args).and_return(request_double)

    expect(vbms_client).to receive(:send_request).at_most(:twice).with(
      request_double
    ).and_return(
      return_val
    )
  end

  def get_vbms_fixture(path)
    get_fixture("vbms/#{path}").map { |r| OpenStruct.new(r) }
  end

  context 'VBMS is available' do
    before do
      allow(VBMS::Client).to receive(:from_env_vars).and_return(vbms_client)

      stub_vbms_client_request(
        'FindDocumentVersionReference',
        file_number,
        get_vbms_fixture('find_document_version_reference')
      )
    end

    describe '#get_letter' do
      context 'with a document in the users folder' do
        let(:content) { File.read('spec/fixtures/pdf_fill/extras.pdf') }

        before do
          stub_vbms_client_request(
            'GetDocumentContent',
            good_document_id,
            OpenStruct.new(
              document_id: good_document_id,
              content:
            )
          )
        end

        it 'downloads a debt letter' do
          expect(subject.get_letter(good_document_id)).to eq(content)
        end
      end

      context 'with a document not in the users folder' do
        it 'raises an unauthorized error' do
          expect { subject.get_letter(bad_document_id) }.to raise_error(Common::Exceptions::Unauthorized)
        end
      end
    end

    describe '#list_letters' do
      it 'gets letter ids and descriptions' do
        expect(subject.list_letters.to_json).to eq(
          get_fixture('vbms/list_letters').to_json
        )
      end
    end

    describe '#file_name' do
      context 'with a proper document id' do
        it 'returns a filename' do
          expect(subject.file_name(good_document_id)).to eq(
            'DMC - Debt Increase Letter June 03, 2020'
          )
        end
      end

      context 'without a proper document id' do
        it 'raises an unauthorized error' do
          expect { subject.file_name(bad_document_id) }.to raise_error(Common::Exceptions::Unauthorized)
        end
      end
    end
  end

  context 'VBMS is down' do
    before do
      allow(VBMS::Client).to receive(:from_env_vars).and_return(vbms_client)
      allow(vbms_client).to receive(:send_request).and_raise(Common::Client::Errors::ClientError)
    end

    describe '#list_letters' do
      it 'notifies Sentry upon downstream service error', :skip_before do
        expect_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry)
        expect(subject.list_letters.to_json).to eq('[]')
      end
    end
  end
end
