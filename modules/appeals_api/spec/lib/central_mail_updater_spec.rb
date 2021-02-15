# frozen_string_literal: true

require 'rails_helper'
require 'appeals_api/central_mail_updater'

describe AppealsApi::CentralMailUpdater do
  let(:client_stub) { instance_double('CentralMail::Service') }
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:appeal) { create(:notice_of_disagreement) }
  let(:central_mail_response) do
    [{ "uuid": 'ignored',
       "status": 'In Process',
       "errorMessage": '',
       "lastUpdated": '2018-04-25 00:02:39' }]
  end

  before do
    allow(CentralMail::Service).to receive(:new) { client_stub }
    allow(client_stub).to receive(:status).and_return(faraday_response)
  end

  it 'returns early when given without any appeals' do
    expect(described_class.new.call([])).to be_nil
  end

  context 'when central mail response is unsuccessful' do
    before do
      allow(faraday_response).to receive(:success?).and_return(false)
      allow(faraday_response).to receive(:body).and_return('error body')
      allow(faraday_response).to receive(:status).and_return('error status')
      allow(appeal).to receive(:log_message_to_sentry)
    end

    # rubocop:disable RSpec/SubjectStub
    it 'raises an exception and logs to Sentry' do
      allow(subject).to receive(:log_message_to_sentry)

      expect { subject.call([appeal]) }
        .to raise_error(Common::Exceptions::BadGateway)

      expect(subject).to have_received(:log_message_to_sentry)
        .with('Error getting status from Central Mail', :warning, body: 'error body', status: 'error status')
    end
    # rubocop:enable RSpec/SubjectStub
  end

  context 'when central mail response is successful' do
    before do
      allow(faraday_response).to receive(:success?).and_return(true)
      central_mail_response[0][:uuid] = appeal.id
      allow(faraday_response).to receive(:body).at_least(:once).and_return([central_mail_response].to_json)
    end

    it 'updates appeal attributes' do
      subject.call([appeal])
      appeal.reload
      expect(appeal.status).to eq('processing')
    end

    context 'when unknown status passed from central mail' do
      let(:central_mail_response) do
        [{ "uuid": 'ignored',
           "status": 'SOME_UNKNOWN_STATUS',
           "errorMessage": '',
           "lastUpdated": '2018-04-25 00:02:39' }]
      end

      # rubocop:disable RSpec/SubjectStub
      it 'raises an exception and logs to sentry' do
        allow(faraday_response).to receive(:body).at_least(:once).and_return([central_mail_response].to_json)
        allow(subject).to receive(:log_message_to_sentry)

        expect { subject.call([appeal]) }
          .to raise_error(Common::Exceptions::BadGateway)
        expect(subject).to have_received(:log_message_to_sentry)
          .with('Unknown status value from Central Mail API', :warning, status: 'SOME_UNKNOWN_STATUS')
      end
      # rubocop:enable RSpec/SubjectStub
    end

    context 'when appeal object contains an error message' do
      let(:central_mail_response) do
        [{ "uuid": 'ignored',
           "status": 'Error',
           "errorMessage": 'You did a bad',
           "lastUpdated": '2018-04-25 00:02:39' }]
      end

      it 'update appeal details to include error message' do
        subject.call([appeal])
        appeal.reload

        expect(appeal.status).to eq('error')
        expect(appeal.detail).to eq('Downstream status: You did a bad')
      end
    end
  end
end
