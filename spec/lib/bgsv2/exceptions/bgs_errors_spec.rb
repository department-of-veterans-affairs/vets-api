# frozen_string_literal: true

require 'rails_helper'
require 'bgsv2/exceptions/bgs_errors'

RSpec.describe BGSV2::Exceptions::BGSErrors do
  let(:dummy_class) do
    Class.new do
      include BGSV2::Exceptions::BGSErrors
      attr_reader :user

      def initialize
        @user = { icn: '1234' }
      end
    end
  end
  let(:dummy_instance) { dummy_class.new }

  describe '#notify_of_service_exception' do
    context 'large stacktrace with oracle error message and PII returned' do
      it 'logs the oracle error message to Sentry, but not the stacktrace or PII' do
        error_message = File.read('spec/fixtures/bgs/bgs_oracle_error.txt')
        dummy_error = StandardError.new(error_message)
        expect(dummy_instance).to receive(:log_message_to_sentry).with(
          'ORA-12899: value too large for column "CORPPROD"."VNP_PERSON"."MIDDLE_NM" (actual: 52, maximum: 30)',
          :error,
          { icn: '1234' },
          { team: 'vfs-ebenefits' }
        )
        expect do
          dummy_instance.notify_of_service_exception(dummy_error, 'dummy_method')
        end.to raise_error(BGSV2::ServiceException)
      end
    end

    context 'error not related to oracle' do
      it "raises a BGS::ServiceException with BGS's raw error message" do
        dummy_error = StandardError.new('(ns0:Server) insertBenefitClaim: City is null')
        expect(dummy_instance).not_to receive(:log_message_to_sentry)
        expect do
          dummy_instance.notify_of_service_exception(dummy_error, 'dummy_method')
        end.to raise_error(BGSV2::ServiceException)
      end
    end

    context 'no error message' do
      it 'raises a BGS::ServiceException' do
        dummy_error = StandardError.new
        expect(dummy_instance).not_to receive(:log_message_to_sentry)
        expect do
          dummy_instance.notify_of_service_exception(dummy_error, 'dummy_method')
        end.to raise_error(BGSV2::ServiceException)
      end
    end
  end
end
