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
  let(:current_user) { build(:evss_user, :loa3) }

  def allow_logger_to_receive_error
    allow(Rails.logger).to receive(:error)
  end

  def expect_logger_error(error_message)
    expect(Rails.logger).to have_received(:error).with(error_message)
  end

  def submit_form(form)
    described_class.new(current_user).submit_form(form)
  end

  describe '#submit_form' do
    context 'when successful' do
      it "returns an object that includes 'success', 'formSubmissionId', and 'timestamp'",
         run_at: 'Fri, 20 Oct 2023 19:41:58 GMT' do
        VCR.use_cassette(
          'form1010_ezr/authorized_submit',
          VCR::MATCH_EVERYTHING.merge(erb: true)
        ) do
          submission_response = submit_form(form)

          expect(submission_response).to be_a(Object)
          expect(submission_response).to eq(
            {
              success: true,
              formSubmissionId: 432_137_192,
              timestamp: '2023-10-20T14:41:58.948-05:00'
            }
          )
        end
      end
    end

    context 'post-filling required fields' do
      before do
        allow(current_user).to receive(:icn).and_return('1013032368V065534')
      end

      it 'adds the required fields to the form hash and returns a successful response',
         run_at: 'Fri, 08 Feb 2019 02:50:45 GMT' do
        form_sans_required_fields =
          form.except(
            'isEssentialAcaCoverage',
            'vaMedicalFacility'
          )

        VCR.use_cassette(
          'hca/ee/lookup_user',
          VCR::MATCH_EVERYTHING.merge(erb: true)
        ) do
          submit_form = submit_form(form_sans_required_fields)

          expect(submit_form).to eq(
            {
              success: true,
              formSubmissionId: 40_124_668_140,
              timestamp: '2023-06-25T04:59:39.345-05:00'
            }
          )
        end
      end
    end

    context 'when an error occurs' do
      context 'schema validation failure' do
        before do
          allow_logger_to_receive_error
        end

        it 'logs and raises a StandardError' do
          expect { submit_form({}) }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::SchemaValidationErrors)
            expect(e.errors[0].title).to eq('Validation error')
            expect(e.errors[0].detail).to include(
              "The property '#/' did not contain a required property of 'privacyAgreementAccepted'"
            )
            expect(e.errors[0].status).to eq('422')
          end
          expect_logger_error('10-10EZR form validation failed. Form does not match schema.')
        end
      end

      context 'any other error' do
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
            submit_form(form)
          end.to raise_error(
            StandardError, 'Uh oh. Some bad error occurred.'
          )
          expect_logger_error('10-10EZR form submission failed: Uh oh. Some bad error occurred.')
        end
      end
    end
  end
end
