# frozen_string_literal: true

require 'rails_helper'
# require Rails.root.join('spec', 'lib', 'sentry_logging_spec_helper.rb')

describe AppealsApi::CentralMailStatus, type: :concern do
  # include_examples 'a sentry logger'

  let(:client_stub) { instance_double('CentralMail::Service') }
  let(:faraday_response) { instance_double('Faraday::Response') }
  let!(:upload) { create(:notice_of_disagreement) }
  let(:in_process_element) do
    [{ "uuid": 'ignored',
       "status": 'In Process',
       "errorMessage": '',
       "lastUpdated": '2018-04-25 00:02:39' }]
  end

  # let(:error_element) do
  #   [{ "uuid": 'ignored',
  #      "status": 'Error',
  #      "errorMessage": 'Very bad',
  #      "lastUpdated": '2018-04-25 00:02:39' }]
  # end

  describe ".refresh_statuses_using_central_mail!" do
    context "when there are no appeals to update" do
      it "returns nil" do
        appeals = []
        expect(AppealsApi::HigherLevelReview.refresh_statuses_using_central_mail!(appeals)).to be_nil
      end
    end

    context "when central mail response is unsuccessful" do
      it "raises an exception" do
        expect(CentralMail::Service).to receive(:new) { client_stub }
        expect(client_stub).to receive(:status).and_return(faraday_response)
        expect(faraday_response).to receive(:success?).and_return(false)
        in_process_element[0]['uuid'] = upload.id
        expect(faraday_response).to receive(:body).at_least(:once).and_return([in_process_element].to_json)
        expect(faraday_response).to receive(:status).at_least(:once).and_return([in_process_element].flatten[0][:status])

        appeals = [upload]
        expect { AppealsApi::HigherLevelReview.refresh_statuses_using_central_mail!(appeals) }.to raise_error(Common::Exceptions::BadGateway)
        # expect(upload).to receive(:log_message_to_sentry)
      end
    end

    context "when central mail response is successful" do
      context "when #update_status_using_central_mail_status!' is called" do
        it "updates the appeal's attributes" do
          expect(CentralMail::Service).to receive(:new) { client_stub }
          expect(client_stub).to receive(:status).and_return(faraday_response)
          expect(faraday_response).to receive(:success?).and_return(true)
          in_process_element[0]['uuid'] = upload.id
          expect(faraday_response).to receive(:body).at_least(:once).and_return([in_process_element].to_json)

          with_settings(Settings.modules_appeals_api, higher_level_review_updater_enabled: true) do
            appeals = [upload]
            AppealsApi::HigherLevelReview.refresh_statuses_using_central_mail!(appeals)
            upload.reload
            expect(upload.status).to eq('processing')
          end
        end

        context "when unknown status passed from central mail" do
          it "raises an error" do
            expect { upload.update_status_using_central_mail_status!(status: "pumpkins") }.to raise_error(Common::Exceptions::BadGateway)
          end

          it "logs to Sentry" do

          end
        end

        context "when appeal object contains an error message" do
          it "updates appeal details to include error message" do
            upload.update_status_using_central_mail_status!('Error', 'You did a bad')
            upload.reload
            expect(upload.status).to eq('error')
            expect(upload.detail).to eq('Downstream status: You did a bad')
          end
        end
      end
    end
  end

  context "verifying our status structures" do
    it "fails if one or more CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES keys or values is mismatched" do
      expect(status_attributes_valid?).to be true
    end

    it "fails if error statuses is mismatched" do
      expect(error_statuses_valid?).to be true
    end

    it "fails if remaining statuses is mismatched" do
      expect(statuses_valid?).to be true
    end
  end

  def status_attributes_valid?
    # TODO: need better solution for the constants here
    subject::CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES.values.all? do |attributes|
      [:status, 'status'].all? do |status|
        !attributes.key?(status) || attributes[status].in?(subject::STATUSES)
      end
    end
  end

  def error_statuses_valid?
    # TODO: need better solution for the constants here
    subject::CENTRAL_MAIL_ERROR_STATUSES.all? do |error_status|
      subject::CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES.keys.include?(error_status)
    end
  end

  def statuses_valid?
    # TODO: need better solution for the constants here
    [*subject::RECEIVED_OR_PROCESSING, *subject::COMPLETE_STATUSES].all? { |status| subject::STATUSES.include?(status) }
  end
end
