# frozen_string_literal: true

require 'rails_helper'
require 'hca/enrollment_eligibility/service'

describe HCA::EnrollmentEligibility::Service do
  describe '#get_ezr_data' do
    let(:veteran_data) do
      data = JSON.parse(File.read('spec/fixtures/form1010_ezr/veteran_data.json'))
      financial_info = data['nonPrefill']['previousFinancialInfo']

      data.delete('nonPrefill')
      data.merge('previousFinancialInfo' => financial_info)
    end

    def expect_veteran_data_to_match(veteran_data)
      VCR.use_cassette(
        'form1010_ezr/lookup_user_with_ezr_prefill_data',
        match_requests_on: %i[method uri body], erb: true
      ) do
        expect(
          described_class.new.get_ezr_data(
            '1012829228V424035'
          ).to_h.deep_stringify_keys
        ).to eq(veteran_data)
      end
    end

    context "when 'ezr_prefill_contacts' is disabled" do
      before do
        allow(Flipper).to receive(:enabled?).with(:ezr_prefill_contacts).and_return(false)
      end

      context "and 'ezr_form_prefill_with_providers_and_dependents' flipper is enabled" do
        before do
          allow(Flipper).to receive(:enabled?).with(:ezr_form_prefill_with_providers_and_dependents).and_return(true)
        end

        it 'gets Veteran data without contacts and with providers and dependents' do
          expect_veteran_data_to_match(veteran_data.except('veteranContacts'))
        end
      end

      context "and 'ezr_form_prefill_with_providers_and_dependents' flipper is disabled" do
        before do
          allow(Flipper).to receive(:enabled?).with(:ezr_form_prefill_with_providers_and_dependents).and_return(false)
        end

        it 'gets Veteran data with without contacts, providers, or dependents' do
          expect_veteran_data_to_match(veteran_data.except('providers', 'dependents', 'veteranContacts'))
        end
      end
    end

    context "when 'ezr_prefill_contacts' is enabled" do
      before do
        allow(Flipper).to receive(:enabled?).with(:ezr_prefill_contacts).and_return(true)
      end

      context "and 'ezr_form_prefill_with_providers_and_dependents' flipper is enabled" do
        before do
          allow(Flipper).to receive(:enabled?).with(:ezr_form_prefill_with_providers_and_dependents).and_return(true)
        end

        it 'gets Veteran data with contacts and with providers and dependents' do
          expect_veteran_data_to_match(veteran_data)
        end
      end

      context "and 'ezr_form_prefill_with_providers_and_dependents' flipper is disabled" do
        before do
          allow(Flipper).to receive(:enabled?).with(:ezr_form_prefill_with_providers_and_dependents).and_return(false)
        end

        it 'gets Veteran data with without contacts and with providers and dependents' do
          expect_veteran_data_to_match(veteran_data.except('providers', 'dependents'))
        end
      end
    end
  end

  describe '#parse_es_date' do
    context 'with an invalid date' do
      it 'returns nil and logs the date' do
        service = described_class.new
        expect(service).to receive(:log_exception_to_sentry).with(instance_of(Date::Error))

        expect(
          service.send(:parse_es_date, 'f')
        ).to be_nil

        expect(
          PersonalInformationLog.where(error_class: 'Form1010Ezr DateError').last.data
        ).to eq('f')
      end
    end
  end

  describe '#lookup_user' do
    context 'with a user that has an ineligibility_reason' do
      it 'gets the ineligibility_reason', run_at: 'Wed, 13 Feb 2019 09:20:47 GMT' do
        VCR.use_cassette(
          'hca/ee/lookup_user_ineligibility_reason',
          VCR::MATCH_EVERYTHING.merge(erb: true)
        ) do
          expect(
            described_class.new.lookup_user('0000001013030524V532318000000')
          ).to eq(
            enrollment_status: 'Not Eligible; Ineligible Date',
            application_date: '2018-01-24T00:00:00.000-06:00',
            enrollment_date: nil,
            preferred_facility: '987 - CHEY6',
            ineligibility_reason: 'for testing',
            effective_date: '2019-01-25T09:04:04.000-06:00',
            primary_eligibility: 'HUMANITARIAN EMERGENCY',
            veteran: 'false',
            priority_group: nil,
            can_submit_financial_info: true
          )
        end
      end
    end

    context "when the user's financial info has already been submitted for the prior calendar year" do
      before { Timecop.freeze(DateTime.new(2023, 2, 3)) }
      after { Timecop.return }

      it "sets the 'can_submit_financial_info' key to false", run_at: 'Mon, 04 Dec 2023 22:32:14 GMT' do
        VCR.use_cassette(
          'hca/ee/lookup_user_can_submit_financial_info',
          { match_requests_on: %i[method uri body], erb: true }
        ) do
          expect(
            described_class.new.lookup_user('1013144622V807216')
          ).to eq(
            enrollment_status: 'Pending; Other',
            application_date: nil,
            enrollment_date: nil,
            preferred_facility: nil,
            ineligibility_reason: nil,
            effective_date: '2019-09-08T22:23:05.000-05:00',
            primary_eligibility: 'NSC',
            veteran: 'true',
            priority_group: nil,
            can_submit_financial_info: false
          )
        end
      end
    end

    it 'lookups the user through the hca ee api', run_at: 'Fri, 08 Feb 2019 02:50:45 GMT' do
      VCR.use_cassette(
        'hca/ee/lookup_user',
        VCR::MATCH_EVERYTHING.merge(erb: true)
      ) do
        expect(
          described_class.new.lookup_user('1013032368V065534')
        ).to eq(
          enrollment_status: 'Verified',
          application_date: '2018-12-27T00:00:00.000-06:00',
          enrollment_date: '2018-12-27T17:15:39.000-06:00',
          preferred_facility: '988 - DAYT20',
          ineligibility_reason: nil,
          effective_date: '2019-01-02T21:58:55.000-06:00',
          primary_eligibility: 'SC LESS THAN 50%',
          veteran: 'true',
          priority_group: 'Group 3',
          can_submit_financial_info: true
        )
      end
    end
  end
end
