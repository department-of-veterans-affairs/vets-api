# frozen_string_literal: true

require 'rails_helper'
require 'lgy/service'

RSpec.describe SavedClaim::CoeClaim do
  describe '#send_to_lgy(edipi:, icn:)' do
    it 'logs an error to sentry if edipi is nil' do
      coe_claim = create(:coe_claim)
      allow(coe_claim).to receive(:prepare_form_data).and_return({})
      allow_any_instance_of(LGY::Service).to receive(:put_application).and_return({})
      expect(Rails.logger).to receive(:error).with(/COE application cannot be submitted without an edipi!/)
      coe_claim.send_to_lgy(edipi: nil, icn: nil)
    end

    it 'logs an error to sentry if edipi is an empty string' do
      coe_claim = create(:coe_claim)
      allow(coe_claim).to receive(:prepare_form_data).and_return({})
      allow_any_instance_of(LGY::Service).to receive(:put_application).and_return({})
      expect(Rails.logger).to receive(:error).with(/COE application cannot be submitted without an edipi!/)
      coe_claim.send_to_lgy(edipi: '', icn: nil)
    end

    it 'sends the right data to LGY' do
      # rubocop:disable Layout/LineLength
      coe_claim = create(:coe_claim, form: '{"relevantPriorLoans":[{"dateRange":{"from":"2017-01-01T00:00:00.000Z","to":""},"propertyAddress":{"propertyAddress1":"234","propertyAddress2":"234","propertyCity":"asdf","propertyState":"AL","propertyZip":"11111"},"propertyOwned":false,"vaLoanNumber":"123123123123","intent":"IRRRL"},{"dateRange":{"from":"2010-01-01T00:00:00.000Z","to":"2011-01-01T00:00:00.000Z"},"propertyAddress":{"propertyAddress1":"939393","propertyAddress2":"234","propertyCity":"asdf","propertyState":"AL","propertyZip":"11111"},"propertyOwned":true,"vaLoanNumber":"123123123123","intent":"REFI"}],"vaLoanIndicator":true,"periodsOfService":[{"serviceBranch":"Air Force","dateRange":{"from":"2000-01-01T00:00:00.000Z","to":"2010-01-16T00:00:00.000Z"}}],"identity":"ADSM","contactPhone":"2223334444","contactEmail":"vet@example.com","fullName":{"first":"Eddie","middle":"Joseph","last":"Caldwell"},"dateOfBirth":"1933-10-27","applicantAddress":{"country":"USA","street":"123 ANY ST","city":"ANYTOWN","state":"AL","postalCode":"54321"},"privacyAgreementAccepted":true}')
      # rubocop:enable Layout/LineLength
      expected_prepared_form_data = {
        'status' => 'SUBMITTED',
        'veteran' => {
          'firstName' => 'Eddie',
          'middleName' => 'Joseph',
          'lastName' => 'Caldwell',
          'suffixName' => '',
          'dateOfBirth' => '1933-10-27',
          'vetAddress1' => '123 ANY ST',
          'vetAddress2' => '',
          'vetCity' => 'ANYTOWN',
          'vetState' => 'AL',
          'vetZip' => '54321',
          'vetZipSuffix' => nil,
          'mailingAddress1' => '123 ANY ST',
          'mailingAddress2' => '',
          'mailingCity' => 'ANYTOWN',
          'mailingState' => 'AL',
          'mailingZip' => '54321',
          'mailingZipSuffix' => '',
          'contactPhone' => '2223334444',
          'contactEmail' => 'vet@example.com',
          'vaLoanIndicator' => true,
          'vaHomeOwnIndicator' => true,
          'activeDutyIndicator' => true,
          'disabilityIndicator' => false
        },
        'relevantPriorLoans' => [{
          'vaLoanNumber' => '123123123123',
          'startDate' => '2017-01-01T00:00:00.000Z',
          'paidOffDate' => '',
          'loanAmount' => nil,
          'loanEntitlementCharged' => nil,
          'propertyOwned' => false,
          'oneTimeRestorationRequested' => false,
          'irrrlRequested' => true,
          'cashoutRefinaceRequested' => false,
          'noRestorationEntitlementIndicator' => false,
          'homeSellIndicator' => nil,
          'propertyAddress1' => '234',
          'propertyAddress2' => '234',
          'propertyCity' => 'asdf',
          'propertyState' => 'AL',
          'propertyCounty' => '',
          'propertyZip' => '11111',
          'propertyZipSuffix' => ''
        }, {
          'vaLoanNumber' => '123123123123',
          'startDate' => '2010-01-01T00:00:00.000Z',
          'paidOffDate' => '2011-01-01T00:00:00.000Z',
          'loanAmount' => nil,
          'loanEntitlementCharged' => nil,
          'propertyOwned' => true,
          'oneTimeRestorationRequested' => false,
          'irrrlRequested' => false,
          'cashoutRefinaceRequested' => true,
          'noRestorationEntitlementIndicator' => false,
          'homeSellIndicator' => nil,
          'propertyAddress1' => '939393',
          'propertyAddress2' => '234',
          'propertyCity' => 'asdf',
          'propertyState' => 'AL',
          'propertyCounty' => '',
          'propertyZip' => '11111',
          'propertyZipSuffix' => ''
        }],
        'periodsOfService' => [{
          'enteredOnDuty' => '2000-01-01T00:00:00.000Z',
          'releasedActiveDuty' => '2010-01-16T00:00:00.000Z',
          'militaryBranch' => 'AIR_FORCE',
          'serviceType' => 'ACTIVE_DUTY',
          'disabilityIndicator' => false
        }]
      }
      expect_any_instance_of(LGY::Service)
        .to receive(:put_application)
        .with(payload: expected_prepared_form_data)
        .and_return({})
      coe_claim.send_to_lgy(edipi: '1222333222', icn: '1112227772V019333')
    end

    context 'send AIR_FORCE as branch for Air National Guard to LGY' do
      it 'sends the right data to LGY' do
        # rubocop:disable Layout/LineLength
        coe_claim = create(:coe_claim, form: '{"relevantPriorLoans":[{"dateRange":{"from":"2017-01-01T00:00:00.000Z","to":""},"propertyAddress":{"propertyAddress1":"234","propertyAddress2":"234","propertyCity":"asdf","propertyState":"AL","propertyZip":"11111"},"propertyOwned":false,"vaLoanNumber":"123123123123", "intent":"IRRRL"},{"dateRange":{"from":"2010-01-01T00:00:00.000Z","to":"2011-01-01T00:00:00.000Z"},"propertyAddress":{"propertyAddress1":"939393","propertyAddress2":"234","propertyCity":"asdf","propertyState":"AL","propertyZip":"11111"},"propertyOwned":true,"vaLoanNumber":"123123123123", "intent":"REFI"}],"vaLoanIndicator":true,"periodsOfService":[{"serviceBranch":"Air National Guard","dateRange":{"from":"2000-01-01T00:00:00.000Z","to":"2010-01-16T00:00:00.000Z"}}],"identity":"ADSM","contactPhone":"2223334444","contactEmail":"vet@example.com","fullName":{"first":"Eddie","middle":"Joseph","last":"Caldwell"},"dateOfBirth":"1933-10-27","applicantAddress":{"country":"USA","street":"123 ANY ST","city":"ANYTOWN","state":"AL","postalCode":"54321"},"privacyAgreementAccepted":true}')
        # rubocop:enable Layout/LineLength
        expected_prepared_form_data = {
          'status' => 'SUBMITTED',
          'veteran' => {
            'firstName' => 'Eddie',
            'middleName' => 'Joseph',
            'lastName' => 'Caldwell',
            'suffixName' => '',
            'dateOfBirth' => '1933-10-27',
            'vetAddress1' => '123 ANY ST',
            'vetAddress2' => '',
            'vetCity' => 'ANYTOWN',
            'vetState' => 'AL',
            'vetZip' => '54321',
            'vetZipSuffix' => nil,
            'mailingAddress1' => '123 ANY ST',
            'mailingAddress2' => '',
            'mailingCity' => 'ANYTOWN',
            'mailingState' => 'AL',
            'mailingZip' => '54321',
            'mailingZipSuffix' => '',
            'contactPhone' => '2223334444',
            'contactEmail' => 'vet@example.com',
            'vaLoanIndicator' => true,
            'vaHomeOwnIndicator' => true,
            'activeDutyIndicator' => true,
            'disabilityIndicator' => false
          },
          'relevantPriorLoans' => [{
            'vaLoanNumber' => '123123123123',
            'startDate' => '2017-01-01T00:00:00.000Z',
            'paidOffDate' => '',
            'loanAmount' => nil,
            'loanEntitlementCharged' => nil,
            'propertyOwned' => false,
            'oneTimeRestorationRequested' => false,
            'irrrlRequested' => true,
            'cashoutRefinaceRequested' => false,
            'noRestorationEntitlementIndicator' => false,
            'homeSellIndicator' => nil,
            'propertyAddress1' => '234',
            'propertyAddress2' => '234',
            'propertyCity' => 'asdf',
            'propertyState' => 'AL',
            'propertyCounty' => '',
            'propertyZip' => '11111',
            'propertyZipSuffix' => ''
          }, {
            'vaLoanNumber' => '123123123123',
            'startDate' => '2010-01-01T00:00:00.000Z',
            'paidOffDate' => '2011-01-01T00:00:00.000Z',
            'loanAmount' => nil,
            'loanEntitlementCharged' => nil,
            'propertyOwned' => true,
            'oneTimeRestorationRequested' => false,
            'irrrlRequested' => false,
            'cashoutRefinaceRequested' => true,
            'noRestorationEntitlementIndicator' => false,
            'homeSellIndicator' => nil,
            'propertyAddress1' => '939393',
            'propertyAddress2' => '234',
            'propertyCity' => 'asdf',
            'propertyState' => 'AL',
            'propertyCounty' => '',
            'propertyZip' => '11111',
            'propertyZipSuffix' => ''
          }],
          'periodsOfService' => [{
            'enteredOnDuty' => '2000-01-01T00:00:00.000Z',
            'releasedActiveDuty' => '2010-01-16T00:00:00.000Z',
            'militaryBranch' => 'AIR_FORCE',
            'serviceType' => 'RESERVE_NATIONAL_GUARD',
            'disabilityIndicator' => false
          }]
        }
        expect_any_instance_of(LGY::Service)
          .to receive(:put_application)
          .with(payload: expected_prepared_form_data)
          .and_return({})
        coe_claim.send_to_lgy(edipi: '1222333222', icn: '1112227772V019333')
      end
    end

    context 'send MARINES as branch for Marine Corps Reserve to LGY' do
      it 'sends the right data to LGY' do
        # rubocop:disable Layout/LineLength
        coe_claim = create(:coe_claim, form: '{"relevantPriorLoans":[{"dateRange":{"from":"2017-01-01T00:00:00.000Z","to":""},"propertyAddress":{"propertyAddress1":"234","propertyAddress2":"234","propertyCity":"asdf","propertyState":"AL","propertyZip":"11111"},"propertyOwned":false,"vaLoanNumber":"123123123123","intent":"IRRRL"},{"dateRange":{"from":"2010-01-01T00:00:00.000Z","to":"2011-01-01T00:00:00.000Z"},"propertyAddress":{"propertyAddress1":"939393","propertyAddress2":"234","propertyCity":"asdf","propertyState":"AL","propertyZip":"11111"},"propertyOwned":true,"vaLoanNumber":"123123123123","intent":"REFI"}],"vaLoanIndicator":true,"periodsOfService":[{"serviceBranch":"Marine Corps Reserve","dateRange":{"from":"2000-01-01T00:00:00.000Z","to":"2010-01-16T00:00:00.000Z"}}],"identity":"ADSM","contactPhone":"2223334444","contactEmail":"vet@example.com","fullName":{"first":"Eddie","middle":"Joseph","last":"Caldwell"},"dateOfBirth":"1933-10-27","applicantAddress":{"country":"USA","street":"123 ANY ST","city":"ANYTOWN","state":"AL","postalCode":"54321"},"privacyAgreementAccepted":true}')
        # rubocop:enable Layout/LineLength
        expected_prepared_form_data = {
          'status' => 'SUBMITTED',
          'veteran' => {
            'firstName' => 'Eddie',
            'middleName' => 'Joseph',
            'lastName' => 'Caldwell',
            'suffixName' => '',
            'dateOfBirth' => '1933-10-27',
            'vetAddress1' => '123 ANY ST',
            'vetAddress2' => '',
            'vetCity' => 'ANYTOWN',
            'vetState' => 'AL',
            'vetZip' => '54321',
            'vetZipSuffix' => nil,
            'mailingAddress1' => '123 ANY ST',
            'mailingAddress2' => '',
            'mailingCity' => 'ANYTOWN',
            'mailingState' => 'AL',
            'mailingZip' => '54321',
            'mailingZipSuffix' => '',
            'contactPhone' => '2223334444',
            'contactEmail' => 'vet@example.com',
            'vaLoanIndicator' => true,
            'vaHomeOwnIndicator' => true,
            'activeDutyIndicator' => true,
            'disabilityIndicator' => false
          },
          'relevantPriorLoans' => [{
            'vaLoanNumber' => '123123123123',
            'startDate' => '2017-01-01T00:00:00.000Z',
            'paidOffDate' => '',
            'loanAmount' => nil,
            'loanEntitlementCharged' => nil,
            'propertyOwned' => false,
            'oneTimeRestorationRequested' => false,
            'irrrlRequested' => true,
            'cashoutRefinaceRequested' => false,
            'noRestorationEntitlementIndicator' => false,
            'homeSellIndicator' => nil,
            'propertyAddress1' => '234',
            'propertyAddress2' => '234',
            'propertyCity' => 'asdf',
            'propertyState' => 'AL',
            'propertyCounty' => '',
            'propertyZip' => '11111',
            'propertyZipSuffix' => ''
          }, {
            'vaLoanNumber' => '123123123123',
            'startDate' => '2010-01-01T00:00:00.000Z',
            'paidOffDate' => '2011-01-01T00:00:00.000Z',
            'loanAmount' => nil,
            'loanEntitlementCharged' => nil,
            'propertyOwned' => true,
            'oneTimeRestorationRequested' => false,
            'irrrlRequested' => false,
            'cashoutRefinaceRequested' => true,
            'noRestorationEntitlementIndicator' => false,
            'homeSellIndicator' => nil,
            'propertyAddress1' => '939393',
            'propertyAddress2' => '234',
            'propertyCity' => 'asdf',
            'propertyState' => 'AL',
            'propertyCounty' => '',
            'propertyZip' => '11111',
            'propertyZipSuffix' => ''
          }],
          'periodsOfService' => [{
            'enteredOnDuty' => '2000-01-01T00:00:00.000Z',
            'releasedActiveDuty' => '2010-01-16T00:00:00.000Z',
            'militaryBranch' => 'MARINES',
            'serviceType' => 'RESERVE_NATIONAL_GUARD',
            'disabilityIndicator' => false
          }]
        }
        expect_any_instance_of(LGY::Service)
          .to receive(:put_application)
          .with(payload: expected_prepared_form_data)
          .and_return({})
        coe_claim.send_to_lgy(edipi: '1222333222', icn: '1112227772V019333')
      end
    end

    context 'send MARINES as branch for Marine Corps to LGY' do
      it 'sends the right data to LGY' do
        # rubocop:disable Layout/LineLength
        coe_claim = create(:coe_claim, form: '{"relevantPriorLoans":[{"dateRange":{"from":"2017-01-01T00:00:00.000Z","to":""},"propertyAddress":{"propertyAddress1":"234","propertyAddress2":"234","propertyCity":"asdf","propertyState":"AL","propertyZip":"11111"},"propertyOwned":false,"vaLoanNumber":"123123123123","intent":"IRRRL"},{"dateRange":{"from":"2010-01-01T00:00:00.000Z","to":"2011-01-01T00:00:00.000Z"},"propertyAddress":{"propertyAddress1":"939393","propertyAddress2":"234","propertyCity":"asdf","propertyState":"AL","propertyZip":"11111"},"propertyOwned":true,"vaLoanNumber":"123123123123","intent":"REFI"}],"vaLoanIndicator":true,"periodsOfService":[{"serviceBranch":"Marine Corps","dateRange":{"from":"2000-01-01T00:00:00.000Z","to":"2010-01-16T00:00:00.000Z"}}],"identity":"ADSM","contactPhone":"2223334444","contactEmail":"vet@example.com","fullName":{"first":"Eddie","middle":"Joseph","last":"Caldwell"},"dateOfBirth":"1933-10-27","applicantAddress":{"country":"USA","street":"123 ANY ST","city":"ANYTOWN","state":"AL","postalCode":"54321"},"privacyAgreementAccepted":true}')
        # rubocop:enable Layout/LineLength
        expected_prepared_form_data = {
          'status' => 'SUBMITTED',
          'veteran' => {
            'firstName' => 'Eddie',
            'middleName' => 'Joseph',
            'lastName' => 'Caldwell',
            'suffixName' => '',
            'dateOfBirth' => '1933-10-27',
            'vetAddress1' => '123 ANY ST',
            'vetAddress2' => '',
            'vetCity' => 'ANYTOWN',
            'vetState' => 'AL',
            'vetZip' => '54321',
            'vetZipSuffix' => nil,
            'mailingAddress1' => '123 ANY ST',
            'mailingAddress2' => '',
            'mailingCity' => 'ANYTOWN',
            'mailingState' => 'AL',
            'mailingZip' => '54321',
            'mailingZipSuffix' => '',
            'contactPhone' => '2223334444',
            'contactEmail' => 'vet@example.com',
            'vaLoanIndicator' => true,
            'vaHomeOwnIndicator' => true,
            'activeDutyIndicator' => true,
            'disabilityIndicator' => false
          },
          'relevantPriorLoans' => [{
            'vaLoanNumber' => '123123123123',
            'startDate' => '2017-01-01T00:00:00.000Z',
            'paidOffDate' => '',
            'loanAmount' => nil,
            'loanEntitlementCharged' => nil,
            'propertyOwned' => false,
            'oneTimeRestorationRequested' => false,
            'irrrlRequested' => true,
            'cashoutRefinaceRequested' => false,
            'noRestorationEntitlementIndicator' => false,
            'homeSellIndicator' => nil,
            'propertyAddress1' => '234',
            'propertyAddress2' => '234',
            'propertyCity' => 'asdf',
            'propertyState' => 'AL',
            'propertyCounty' => '',
            'propertyZip' => '11111',
            'propertyZipSuffix' => ''
          }, {
            'vaLoanNumber' => '123123123123',
            'startDate' => '2010-01-01T00:00:00.000Z',
            'paidOffDate' => '2011-01-01T00:00:00.000Z',
            'loanAmount' => nil,
            'loanEntitlementCharged' => nil,
            'propertyOwned' => true,
            'oneTimeRestorationRequested' => false,
            'irrrlRequested' => false,
            'cashoutRefinaceRequested' => true,
            'noRestorationEntitlementIndicator' => false,
            'homeSellIndicator' => nil,
            'propertyAddress1' => '939393',
            'propertyAddress2' => '234',
            'propertyCity' => 'asdf',
            'propertyState' => 'AL',
            'propertyCounty' => '',
            'propertyZip' => '11111',
            'propertyZipSuffix' => ''
          }],
          'periodsOfService' => [{
            'enteredOnDuty' => '2000-01-01T00:00:00.000Z',
            'releasedActiveDuty' => '2010-01-16T00:00:00.000Z',
            'militaryBranch' => 'MARINES',
            'serviceType' => 'ACTIVE_DUTY',
            'disabilityIndicator' => false
          }]
        }
        expect_any_instance_of(LGY::Service)
          .to receive(:put_application)
          .with(payload: expected_prepared_form_data)
          .and_return({})
        coe_claim.send_to_lgy(edipi: '1222333222', icn: '1112227772V019333')
      end
    end

    context 'no loan information' do
      it 'sends the right data to LGY' do
        # rubocop:disable Layout/LineLength
        coe_claim = create(:coe_claim, form: '{"intent":"REFI","vaLoanIndicator":true,"periodsOfService":[{"serviceBranch":"Air Force","dateRange":{"from":"2000-01-01T00:00:00.000Z","to":"2010-01-16T00:00:00.000Z"}}],"identity":"ADSM","contactPhone":"2223334444","contactEmail":"vet@example.com","fullName":{"first":"Eddie","middle":"Joseph","last":"Caldwell"},"dateOfBirth":"1933-10-27","applicantAddress":{"country":"USA","street":"123 ANY ST","city":"ANYTOWN","state":"AL","postalCode":"54321"},"privacyAgreementAccepted":true}')
        # rubocop:enable Layout/LineLength
        expected_prepared_form_data = {
          'status' => 'SUBMITTED',
          'veteran' => {
            'firstName' => 'Eddie',
            'middleName' => 'Joseph',
            'lastName' => 'Caldwell',
            'suffixName' => '',
            'dateOfBirth' => '1933-10-27',
            'vetAddress1' => '123 ANY ST',
            'vetAddress2' => '',
            'vetCity' => 'ANYTOWN',
            'vetState' => 'AL',
            'vetZip' => '54321',
            'vetZipSuffix' => nil,
            'mailingAddress1' => '123 ANY ST',
            'mailingAddress2' => '',
            'mailingCity' => 'ANYTOWN',
            'mailingState' => 'AL',
            'mailingZip' => '54321',
            'mailingZipSuffix' => '',
            'contactPhone' => '2223334444',
            'contactEmail' => 'vet@example.com',
            'vaLoanIndicator' => true,
            'vaHomeOwnIndicator' => false,
            'activeDutyIndicator' => true,
            'disabilityIndicator' => false
          },
          'relevantPriorLoans' => [],
          'periodsOfService' => [{
            'enteredOnDuty' => '2000-01-01T00:00:00.000Z',
            'releasedActiveDuty' => '2010-01-16T00:00:00.000Z',
            'militaryBranch' => 'AIR_FORCE',
            'serviceType' => 'ACTIVE_DUTY',
            'disabilityIndicator' => false
          }]
        }
        expect_any_instance_of(LGY::Service)
          .to receive(:put_application)
          .with(payload: expected_prepared_form_data)
          .and_return({})
        coe_claim.send_to_lgy(edipi: '1222333222', icn: '1112227772V019333')
      end
    end
  end
end
