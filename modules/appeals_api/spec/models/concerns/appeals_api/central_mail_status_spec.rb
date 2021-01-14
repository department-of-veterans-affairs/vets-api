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
          AppealsApi::HigherLevelReview.refresh_statuses_using_central_mail!([upload])

          expect(upload.status).to eq('processing')
        end

        context 'when unknown status passed from central mail' do
          let(:attempt_invalid_update) { upload.update_status_using_central_mail_status!(status: 'pumpkins') }

          it 'raises an exception' do
            expect { attempt_invalid_update }
              .to raise_error(Common::Exceptions::BadGateway)
          end

          it 'logs to Sentry' do
            attempt_invalid_update
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
    let(:local_statuses) { subject::STATUSES }

    it 'fails if one or more CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES keys or values is mismatched' do
      status_hashes = subject::CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES.values
      status_attr_keys = status_hashes.map(&:keys).flatten
      status_attr_values = status_hashes.map { |attr| attr[:status] }.uniq

      expect(local_statuses).to include(*status_attr_values)
      expect(status_attr_keys).not_to include(*status_attr_values)
    end

    it 'fails if error statuses are mismatched' do
      central_mail_statuses = subject::CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES.keys
      error_statuses = subject::CENTRAL_MAIL_ERROR_STATUSES

      expect(central_mail_statuses).to include(*error_statuses)
    end

    it 'fails if remaining statuses are mismatched' do
      additional_statuses = [*subject::RECEIVED_OR_PROCESSING, *subject::COMPLETE_STATUSES]

      expect(local_statuses).to include(*additional_statuses)
    end
  end
end
