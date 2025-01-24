# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/error/soap_error_handler'

describe ClaimsApi::LocalBGS do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  let(:soap_error_handler) { ClaimsApi::SoapErrorHandler.new }

  # Testing potential ways the current check could be tricked
  describe '#all' do
    let(:subject_instance) { subject }

    context 'when an error message gets returns unknown' do
      it 'the soap error handler returns unprocessable' do
        allow(subject_instance).to receive(:make_request).with(endpoint: 'PersonWebServiceBean/PersonWebService',
                                                               action: 'findPersonBySSN',
                                                               body: Nokogiri::XML::DocumentFragment.new(
                                                                 Nokogiri::XML::Document.new
                                                               ),
                                                               key: 'PersonDTO').and_return(:bgs_unknown_error_message)
        begin
          allow(soap_error_handler).to receive(:handle_errors)
            .with(:bgs_unknown_error_message).and_raise(Common::Exceptions::UnprocessableEntity)
          ret = soap_error_handler.send(:handle_errors, :bgs_unknown_error_message)
          expect(ret.class).to_be Array
          expect(ret.size).to eq 1
        rescue => e
          expect(e.message).to include 'Unprocessable Entity'
        end
      end
    end
  end
end
