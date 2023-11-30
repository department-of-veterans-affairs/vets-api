# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HCA::EzrSubmissionJob, type: :job do
  let(:user) { build(:evss_user, :loa3, icn: '1013032368V065534') }
  let(:user_identifier) { HealthCareApplication.get_user_identifier(user) }
  let(:form) do
    get_fixture('form1010_ezr/valid_form')
  end
  let(:encrypted_form) do
    HealthCareApplication::LOCKBOX.encrypt(form.to_json)
  end
  let(:ezr_service) { double }

  describe '#perform' do
    subject do
      described_class.new.perform(encrypted_form, user_identifier)
    end

    before do
      expect(Form1010Ezr::Service).to receive(:new).with(user_identifier).once.and_return(ezr_service)
    end

    context 'when submission has an error' do
      let(:error) { Common::Client::Errors::HTTPError }

      before do
        expect(ezr_service).to receive(:submit_sync).with(form).once.and_raise(error)
      end

      context 'with a validation error' do
        let(:error) { HCA::SOAPParser::ValidationError }

        it 'creates a pii log' do
          subject

          log = PersonalInformationLog.where(error_class: 'EzrValidationError').last
          expect(log.data['form']).to eq(form)
        end
      end
    end

    context 'with a successful submission' do
      it 'calls the service' do
        expect(ezr_service).to receive(:submit_sync).with(form)

        subject
      end
    end
  end
end
