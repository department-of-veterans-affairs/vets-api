# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::CentralMailUpdater do
  let(:client_stub) { instance_double('CentralMail::Service') }
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:appeal_1) { create(:notice_of_disagreement) }
  let(:appeal_2) { create(:notice_of_disagreement) }
  let(:central_mail_response) do
    [{ uuid: appeal_1.id,
       status: 'In Process',
       errorMessage: '',
       lastUpdated: '2018-04-25 00:02:39' }]
  end

  before do
    allow(CentralMail::Service).to receive(:new) { client_stub }
    allow(client_stub).to receive(:status).and_return(faraday_response)
  end

  context 'uses different statuses/attributes matching for nod and hlr' do
    before do
      allow(faraday_response).to receive(:success?).and_return(true)
      central_mail_response[0][:status] = 'VBMS Complete'
    end

    it 'nod accepts VBMS Complete' do
      allow(faraday_response).to receive(:body).at_least(:once).and_return([central_mail_response].to_json)

      subject.call([appeal_1])
      appeal_1.reload
      expect(appeal_1.status).to eq('caseflow')
    end

    it 'hlr accepts VBMS Complete but maps it to success' do
      hlr = create(:higher_level_review)
      central_mail_response[0][:uuid] = hlr.id
      allow(faraday_response).to receive(:body).at_least(:once).and_return([central_mail_response].to_json)

      subject.call([hlr])
      hlr.reload
      expect(hlr.status).to eq('success')
    end

    it 'hlr V2 accepts VBMS Complete and maps it to caseflow' do
      hlr = create(:higher_level_review)
      hlr.update!(api_version: 'V2')
      central_mail_response[0][:uuid] = hlr.id
      allow(faraday_response).to receive(:body).at_least(:once).and_return([central_mail_response].to_json)

      subject.call([hlr])
      hlr.reload
      expect(hlr.api_version).to eq('V2')
      expect(hlr.status).to eq('caseflow')
    end
  end

  context 'when verifying status structures' do
    let(:appeal_statuses) { AppealsApi::NodStatus::STATUSES }

    it 'fails if one or more NOD_CENTRAL_STATUS_ATTRIBUTES keys or values is mismatched' do
      status_hashes = described_class::NOD_CENTRAL_STATUS_ATTRIBUTES.values
      status_attr_keys = status_hashes.map(&:keys).flatten
      status_attr_values = status_hashes.map { |attr| attr[:status] }.uniq

      expect(appeal_statuses).to include(*status_attr_values)
      expect(status_attr_keys).not_to include(*status_attr_values)
    end

    it 'fails if error statuses are mismatched' do
      central_mail_statuses = described_class::NOD_CENTRAL_STATUS_ATTRIBUTES.keys
      error_statuses = described_class::CENTRAL_MAIL_ERROR_STATUSES

      expect(central_mail_statuses).to include(*error_statuses)
    end
  end

  it 'returns early when given without any appeals' do
    expect(described_class.new.call([])).to be_nil
  end

  context 'when central mail response is unsuccessful' do
    before do
      allow(faraday_response).to receive(:success?).and_return(false)
      allow(faraday_response).to receive(:body).and_return('error body')
      allow(faraday_response).to receive(:status).and_return('error status')
    end

    # rubocop:disable RSpec/SubjectStub
    it 'raises an exception and logs to Sentry' do
      allow(subject).to receive(:log_message_to_sentry)

      expect { subject.call([appeal_1]) }
        .to raise_error(Common::Exceptions::BadGateway)

      expect(subject).to have_received(:log_message_to_sentry)
        .with('Error getting status from Central Mail', :warning, body: 'error body', status: 'error status')
    end
    # rubocop:enable RSpec/SubjectStub
  end

  context 'when central mail response is successful' do
    before do
      allow(faraday_response).to receive(:success?).and_return(true)
      central_mail_response[0][:uuid] = appeal_1.id
      allow(faraday_response).to receive(:body).at_least(:once).and_return([central_mail_response].to_json)
    end

    it 'only updates appeal attributes for returned records' do
      subject.call([appeal_1])
      appeal_1.reload
      appeal_2.reload
      expect(appeal_1.status).to eq('processing')
      expect(appeal_2.status).to eq('pending')
    end

    context 'when unknown status passed from central mail' do
      before do
        central_mail_response[0][:status] = 'SOME_UNKNOWN_STATUS'
        allow(faraday_response).to receive(:body).at_least(:once).and_return([central_mail_response].to_json)
      end

      # rubocop:disable RSpec/SubjectStub
      it 'raises an exception and logs to sentry' do
        allow(faraday_response).to receive(:body).at_least(:once).and_return([central_mail_response].to_json)
        allow(subject).to receive(:log_message_to_sentry)

        expect { subject.call([appeal_1]) }
          .to raise_error(Common::Exceptions::BadGateway)
        expect(subject).to have_received(:log_message_to_sentry)
          .with('Unknown status value from Central Mail API', :warning, status: 'SOME_UNKNOWN_STATUS')
      end
      # rubocop:enable RSpec/SubjectStub
    end

    context 'when appeal object contains an error message' do
      before do
        central_mail_response[0][:status] = 'Error'
        central_mail_response[0][:errorMessage] = 'You did a bad'
        allow(faraday_response).to receive(:body).at_least(:once).and_return([central_mail_response].to_json)
      end

      it 'update appeal details to include error message' do
        subject.call([appeal_1])
        appeal_1.reload

        expect(appeal_1.status).to eq('error')
        expect(appeal_1.detail).to eq('Downstream status: You did a bad')
      end
    end

    context 'it ignores central mail responses without a uuid (invalid or missing)' do
      before do
        central_mail_response[1] = {
          status: 'In Process',
          errorMessage: '',
          lastUpdated: '2018-04-25 00:02:39'
        }
        central_mail_response[2] = {
          uuid: '00000000-0000-0000-0000-000000000000',
          status: 'In Process',
          errorMessage: '',
          lastUpdated: '2018-04-25 00:02:39'
        }
        allow(faraday_response).to receive(:body).at_least(:once).and_return([central_mail_response].to_json)
      end

      it 'and only changes' do
        expect { subject.call([appeal_1]) }.not_to raise_error
      end
    end
  end
end
