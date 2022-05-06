# frozen_string_literal: true

require 'rails_helper'

module AppealsApi
  module PdfConstruction
    module SupplementalClaim
      module V2
        describe FormFields do
          let(:form_fields) { described_class.new }

          describe '#veteran_middle_initial' do
            it { expect(form_fields.veteran_middle_initial).to eq 'form1[0].#subform[2].VeteransMiddleInitial1[0]' }
          end

          describe '#ssn_first_three' do
            it {
              expect(form_fields.ssn_first_three).to eq 'form1[0].#subform[2].SocialSecurityNumber_FirstThreeNumbers[0]'
            }
          end

          describe '#ssn_middle_two' do
            it {
              expect(form_fields.ssn_second_two).to eq 'form1[0].#subform[2].SocialSecurityNumber_SecondTwoNumbers[0]'
            }
          end

          describe '#ssn_last_four' do
            it {
              expect(form_fields.ssn_last_four).to eq 'form1[0].#subform[2].SocialSecurityNumber_LastFourNumbers[0]'
            }
          end

          describe '#file_number' do
            it { expect(form_fields.file_number).to eq 'form1[0].#subform[2].VAFileNumber[0]' }
          end

          describe '#veteran_dob_month' do
            it { expect(form_fields.birth_month).to eq 'form1[0].#subform[2].DOBmonth[0]' }
          end

          describe '#veteran_dob_day' do
            it { expect(form_fields.birth_day).to eq 'form1[0].#subform[2].DOBday[0]' }
          end

          describe '#veteran_dob_year' do
            it { expect(form_fields.birth_year).to eq 'form1[0].#subform[2].DOByear[0]' }
          end

          describe '#veteran_service_number' do
            it { expect(form_fields.veteran_service_number).to eq 'form1[0].#subform[2].VeteransServiceNumber[0]' }
          end

          describe '#insurance_policy_number' do
            it { expect(form_fields.insurance_policy_number).to eq 'form1[0].#subform[2].InsurancePolicyNumber[0]' }
          end

          describe '#mailing_address_state' do
            it {
              expect(
                form_fields.mailing_address_state
              ).to eq 'form1[0].#subform[2].CurrentMailingAddress_StateOrProvince[0]'
            }
          end

          describe '#mailing_address_country' do
            it {
              expect(form_fields.mailing_address_country).to eq 'form1[0].#subform[2].CurrentMailingAddress_Country[0]'
            }
          end

          describe '#zip_code_5' do
            it {
              expect(
                form_fields.zip_code_5
              ).to eq 'form1[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]'
            }
          end

          describe '#zip_code_4' do
            it {
              expect(
                form_fields.zip_code_4
              ).to eq 'form1[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]'
            }
          end

          describe '#phone' do
            it { expect(form_fields.phone).to eq 'form1[0].#subform[2].TELEPHONE[0]' }
          end

          describe '#soc_ssoc_opt_in' do
            it { expect(form_fields.soc_ssoc_opt_in).to eq 'form1[0].#subform[2].RadioButtonList[2]' }
          end

          describe '#date_signed' do
            it { expect(form_fields.date_signed).to eq 'form1[0].#subform[3].DATESIGNED[0]' }
          end
        end
      end
    end
  end
end
