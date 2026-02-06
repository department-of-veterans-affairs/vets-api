# frozen_string_literal: true

require 'rails_helper'
require 'bgs/exceptions/bgs_errors'

RSpec.describe BGS::Exceptions::BGSErrors do
  let(:dummy_class) do
    Class.new do
      include BGS::Exceptions::BGSErrors
      attr_reader :user
    end
  end
  let(:dummy_instance) { dummy_class.new }

  describe '#notify_of_service_exception' do
    context 'large stacktrace with oracle error message and PII returned' do
      it 'logs the oracle error message to Sentry, but not the stacktrace or PII' do
        error_message = File.read('spec/fixtures/bgs/bgs_oracle_error.txt')
        dummy_error = StandardError.new(error_message)
        expect(Rails.logger).to receive(:error).with(
          'ORA-12899: value too large for column "CORPPROD"."VNP_PERSON"."MIDDLE_NM" (actual: 52, maximum: 30)',
          include(service: 'bgs')
        )
        expect do
          dummy_instance.notify_of_service_exception(dummy_error, 'dummy_method')
        end.to raise_error(BGS::ServiceException)
      end
    end

    context 'error not related to oracle' do
      it "raises a BGS::ServiceException with BGS's raw error message" do
        dummy_error = StandardError.new('(ns0:Server) insertBenefitClaim: City is null')
        expect(Rails.logger).to receive(:error).with('(ns0:Server) insertBenefitClaim: City is null',
                                                     include(service: 'bgs'))
        expect do
          dummy_instance.notify_of_service_exception(dummy_error, 'dummy_method')
        end.to raise_error(BGS::ServiceException)
      end
    end

    context 'CEST11 errors' do
      it 'raises an error message without PII' do
        error_message = 'CEST11 John Smith john@email.com'
        dummy_error = StandardError.new(error_message)

        expect { dummy_instance.notify_of_service_exception(dummy_error, 'dummy_method') }
          .to raise_error(BGS::ServiceException) do |exception|
            expect(exception.original_body).to eq('CEST11 Error')
          end
      end
    end

    context 'no error message' do
      it 'raises a BGS::ServiceException' do
        dummy_error = StandardError.new
        expect(Rails.logger).to receive(:error).with('StandardError', include(service: 'bgs'))
        expect do
          dummy_instance.notify_of_service_exception(dummy_error, 'dummy_method')
        end.to raise_error(BGS::ServiceException)
      end
    end
  end
end
