# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Profile::Retriever do
  subject(:retriever) { described_class.new(icn:, user_mock_data: true) }

  let(:icn) { I18n.t('ask_va_api')[:test_users][:test_user_228_icn] }
  let(:service) { instance_double(Crm::Service) }
  let(:endpoint) { AskVAApi::Profile::ENDPOINT }
  let(:valid_response) do
    { Data: { FirstName: 'Aminul',
              MiddleName: nil,
              LastName: nil,
              PreferredName: 'test',
              Suffix: 'Jr',
              Gender: 'Female',
              Pronouns: nil,
              Country: 'United States',
              Street: nil,
              City: nil,
              State: nil,
              ZipCode: nil,
              Province: nil,
              BusinessPhone: '(973)767-7598',
              PersonalPhone: nil,
              PersonalEmail: 'aminul.islam@va.gov',
              BusinessEmail: 'test@va.gov',
              SchoolState: nil,
              SchoolFacilityCode: nil,
              ServiceNumber: nil,
              ClaimNumber: nil,
              VeteranServiceStateDate: '1/1/0001 12:00:00 AM',
              VeteranServiceEndDate: '1/1/0001 12:00:00 AM',
              DateOfBirth: '7/22/1991 12:00:00 AM',
              EDIPI: nil },
      message: nil,
      ExceptionOccurred: false,
      ExceptionMessage: nil,
      MessageId: 'e705eb37-4af4-43aa-9248-c8a02ba523eb' }
  end
  let(:entity) { AskVAApi::Profile::Entity.new(valid_response[:Data]) }

  describe '#call' do
    context 'with valid ICN' do
      before do
        allow(service).to receive(:call).with(endpoint:, payload: { icn: }).and_return(valid_response)
      end

      it 'returns an array of Entity objects' do
        expect(retriever.call).to be_an(AskVAApi::Profile::Entity)
      end

      it 'correctly initializes the Entity objects' do
        expect(retriever.call.first_name).to eq(entity.first_name)
      end
    end

    context 'with invalid ICN' do
      let(:icn) { '' }

      it 'raises an ArgumentError' do
        expect { retriever.call }.to raise_error(ErrorHandler::ServiceError, 'ArgumentError: Invalid ICN')
      end
    end

    context 'when the service call fails' do
      subject(:retriever) { described_class.new(icn:) }

      before do
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
        allow_any_instance_of(Crm::Service).to receive(:call).and_raise(StandardError.new('Service error'))
        allow(ErrorHandler).to receive(:handle_service_error).and_return('handled error')
      end

      it 'rescues from errors and calls ErrorHandler' do
        expect { retriever.call }.not_to raise_error
        expect(ErrorHandler).to have_received(:handle_service_error).with(instance_of(StandardError))
      end
    end
  end
end
