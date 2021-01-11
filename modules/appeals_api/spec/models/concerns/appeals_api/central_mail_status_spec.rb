# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::CentralMailStatus, type: :concern do
  let(:client_stub) { instance_double('CentralMail::Service') }
  let(:faraday_response) { instance_double('Faraday::Response') }
  let!(:upload) { create(:notice_of_disagreement) }
  let(:in_process_element) do
    [{ "uuid": 'ignored',
       "status": 'In Process',
       "errorMessage": '',
       "lastUpdated": '2018-04-25 00:02:39' }]
  end

  before do
    allow(CentralMail::Service).to receive(:new) { client_stub }
    allow(client_stub).to receive(:status).and_return(faraday_response)
  end

  describe '.refresh_statuses_using_central_mail!' do
    context 'when there are no appeals to update' do
      it 'returns nil' do
        expect(AppealsApi::HigherLevelReview.refresh_statuses_using_central_mail!([])).to be_nil
      end
    end

    context 'when central mail response is unsuccessful' do
      before do
        allow(faraday_response).to receive(:success?).and_return(false)
        allow(faraday_response).to receive(:body)
        allow(faraday_response).to receive(:status)
        allow(upload).to receive(:log_message_to_sentry)
      end

      it 'raises an exception' do
        expect { AppealsApi::HigherLevelReview.refresh_statuses_using_central_mail!([upload]) }
          .to raise_error(Common::Exceptions::BadGateway)
      end

      it 'logs to Sentry' do
        AppealsApi::HigherLevelReview.refresh_statuses_using_central_mail!([upload])
      rescue Common::Exceptions::BadGateway
        expect(upload).to have_received(:log_message_to_sentry)
      end
    end

    context 'when central mail response is successful' do
      before do
        allow(faraday_response).to receive(:success?).and_return(true)
        in_process_element[0]['uuid'] = upload.id
        allow(faraday_response).to receive(:body).at_least(:once).and_return([in_process_element].to_json)
        allow(upload).to receive(:log_message_to_sentry)
      end

      context 'when #update_status_using_central_mail_status! is called' do
        it 'updates appeal attributes' do
          with_settings(Settings.modules_appeals_api, higher_level_review_updater_enabled: true) do
            AppealsApi::HigherLevelReview.refresh_statuses_using_central_mail!([upload])
            expect(upload.status).to eq('processing')
          end
        end

        context 'when unknown status passed from central mail' do
          it 'raises an exception' do
            expect { upload.update_status_using_central_mail_status!(status: 'pumpkins') }
              .to raise_error(Common::Exceptions::BadGateway)
          end

          it 'logs to Sentry' do
            upload.update_status_using_central_mail_status!(status: 'pumpkins')
          rescue Common::Exceptions::BadGateway
            expect(upload).to have_received(:log_message_to_sentry)
          end
        end

        context 'when appeal object contains an error message' do
          it 'update appeal details to include error message' do
            upload.update_status_using_central_mail_status!('Error', 'You did a bad')
            expect(upload.status).to eq('error')
            expect(upload.detail).to eq('Downstream status: You did a bad')
          end
        end
      end
    end
  end

  context 'when verifying model status structures' do
    it 'fails if one or more CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES keys or values is mismatched' do
      expect(upload.status_attributes_valid?).to be true
    end

    it 'fails if error statuses is mismatched' do
      expect(upload.error_statuses_valid?).to be true
    end

    it 'fails if remaining statuses is mismatched' do
      expect(upload.statuses_valid?).to be true
    end
  end
end
