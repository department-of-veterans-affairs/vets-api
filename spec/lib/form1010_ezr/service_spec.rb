# frozen_string_literal: true

require 'rails_helper'
require 'form1010_ezr/service'

RSpec.describe Form1010Ezr::Service do
  include SchemaMatchers

  let(:form) { get_fixture('form1010_ezr/valid_form') }
  let(:response) do
    double(body: Ox.parse(%(
    <?xml version='1.0' encoding='UTF-8'?>
    <S:Envelope>
      <S:Body>
        <submitFormResponse>
          <status>100</status>
          <formSubmissionId>40124668140</formSubmissionId>
          <message><type>Form successfully received for EE processing</type></message>
          <timeStamp>2023-06-25T04:59:39.345-05:00</timeStamp>
        </submitFormResponse>
      </S:Body>
    </S:Envelope>
     )))
  end
  let(:current_user) { FactoryBot.build(:user, :loa3, icn: nil) }

  def allow_logger_to_receive_error
    allow(Rails.logger).to receive(:error)
  end

  def expect_logger_error(error_message)
    expect(Rails.logger).to have_received(:error).with(error_message)
  end

  describe 'submit_form' do
    context 'when no error occurs' do
      before do
        allow_any_instance_of(Common::Client::Base).to receive(:perform).and_return(response)
      end

      it "returns an object that includes 'success', 'formSubmissionId', and 'timestamp'" do
        submit_form = described_class.new(current_user).submit_form(form)

        expect(submit_form).to be_a(Object)
        expect(submit_form).to eq(
          {
            success: true,
            formSubmissionId: 40_124_668_140,
            timestamp: '2023-06-25T04:59:39.345-05:00'
          }
        )
      end
    end

    context 'when an error occurs' do
      before do
        allow_any_instance_of(
          Common::Client::Base
        ).to receive(:perform).and_raise(
          StandardError.new('Uh oh. Some bad error occurred.')
        )
        allow_logger_to_receive_error
      end

      it 'logs and raises the error' do
        expect do
          described_class.new(current_user).submit_form(form)
        end.to raise_error(
          StandardError, 'Uh oh. Some bad error occurred.'
        )
        expect_logger_error('10-10EZR form submission failed: Uh oh. Some bad error occurred.')
      end
    end
  end

  describe 'validate_form' do
    context 'when there are no validation errors' do
      it 'returns nil' do
        expect(described_class.new(current_user).validate_form(form)).to eq(nil)
      end
    end

    context 'when there are validation errors' do
      before do
        allow_logger_to_receive_error
      end

      it 'logs and raises a StandardError' do
        error_message = '10-10EZR form validation failed. Form does not match schema.'

        expect do
          described_class.new(current_user).validate_form({})
        end.to raise_error(
          StandardError, error_message
        )
        expect_logger_error(error_message)
      end
    end
  end
end
