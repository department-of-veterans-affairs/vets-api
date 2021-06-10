# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/ModuleLength
module AppealsApi
  module PdfConstruction
    module HigherLevelReview
      module V1
        describe FormFields do
          let(:form_fields) { described_class.new }

          describe '#first_name' do
            it { expect(form_fields.first_name).to eq('F[0].#subform[2].VeteransFirstName[0]') }
          end

          describe '#middle_initial' do
            it { expect(form_fields.middle_initial).to eq('F[0].#subform[2].VeteransMiddleInitial1[0]') }
          end

          describe '#last_name' do
            it { expect(form_fields.last_name).to eq('F[0].#subform[2].VeteransLastName[0]') }
          end

          describe '#ssn' do
            describe '#first_three_ssn' do
              it do
                expect(form_fields.first_three_ssn)
                  .to eq('F[0].#subform[2].SocialSecurityNumber_FirstThreeNumbers[0]')
              end
            end

            describe '#second_two_ssn' do
              it do
                expect(form_fields.second_two_ssn)
                  .to eq('F[0].#subform[2].SocialSecurityNumber_SecondTwoNumbers[0]')
              end
            end

            describe '#last_four_ssn' do
              it do
                expect(form_fields.last_four_ssn)
                  .to eq('F[0].#subform[2].SocialSecurityNumber_LastFourNumbers[0]')
              end
            end
          end

          describe '#birth_month' do
            it { expect(form_fields.birth_month).to eq('F[0].#subform[2].DOBmonth[0]') }
          end

          describe '#birth_day' do
            it { expect(form_fields.birth_day).to eq('F[0].#subform[2].DOBday[0]') }
          end

          describe '#birth_year' do
            it { expect(form_fields.birth_year).to eq('F[0].#subform[2].DOByear[0]') }
          end

          describe '#file_number' do
            it { expect(form_fields.file_number).to eq('F[0].#subform[2].VAFileNumber[0]') }
          end

          describe '#service_number' do
            it { expect(form_fields.service_number).to eq('F[0].#subform[2].VeteransServiceNumber[0]') }
          end

          describe '#insurance_policy_number' do
            it { expect(form_fields.insurance_policy_number).to eq('F[0].#subform[2].InsurancePolicyNumber[0]') }
          end

          describe '#claimant_type' do
            it { expect(form_fields.claimant_type(3)).to eq('F[0].#subform[2].ClaimantType[3]') }
          end

          context 'mailing address' do
            describe '#mailing_address_street' do
              it do
                expect(form_fields.mailing_address_street)
                  .to eq('F[0].#subform[2].CurrentMailingAddress_NumberAndStreet[0]')
              end
            end

            describe '#mailing_address_unit_number' do
              it do
                expect(form_fields.mailing_address_unit_number)
                  .to eq('F[0].#subform[2].CurrentMailingAddress_ApartmentOrUnitNumber[0]')
              end
            end

            describe '#mailing_address_city' do
              it { expect(form_fields.mailing_address_city).to eq('F[0].#subform[2].CurrentMailingAddress_City[0]') }
            end

            describe '#mailing_address_state' do
              it do
                expect(form_fields.mailing_address_state)
                  .to eq('F[0].#subform[2].CurrentMailingAddress_StateOrProvince[0]')
              end
            end

            describe '#mailing_address_country' do
              it do
                expect(form_fields.mailing_address_country)
                  .to eq('F[0].#subform[2].CurrentMailingAddress_Country[0]')
              end
            end
          end

          describe 'mailing_address_zip_first_5' do
            it do
              expect(form_fields.mailing_address_zip_first_5)
                .to eq('F[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]')
            end
          end

          describe 'mailing_address_zip_last_4' do
            it do
              expect(form_fields.mailing_address_zip_last_4)
                .to eq('F[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]')
            end
          end

          describe 'veteran_phone_number' do
            it { expect(form_fields.veteran_phone_number).to eq('F[0].#subform[2].TELEPHONE[0]') }
          end

          describe 'veteran_email' do
            it { expect(form_fields.veteran_email).to eq('F[0].#subform[2].EMAIL[0]') }
          end

          describe 'benefit_type' do
            it { expect(form_fields.benefit_type(3)).to eq('F[0].#subform[2].BenefitType[3]') }
          end

          describe '#same_office' do
            it { expect(form_fields.same_office).to eq('F[0].#subform[2].HIGHERLEVELREVIEWCHECKBOX[0]') }
          end

          describe '#informal_conference' do
            it { expect(form_fields.informal_conference).to eq('F[0].#subform[2].INFORMALCONFERENCECHECKBOX[0]') }
          end

          describe '#conference_8_to_10' do
            it { expect(form_fields.conference_8_to_10).to eq('F[0].#subform[2].TIME8TO10AM[0]') }
          end

          describe '#conference_10_to_1230' do
            it { expect(form_fields.conference_10_to_1230).to eq('F[0].#subform[2].TIME10TO1230PM[0]') }
          end

          describe '#conference_1230_to_2' do
            it { expect(form_fields.conference_1230_to_2).to eq('F[0].#subform[2].TIME1230TO2PM[0]') }
          end

          describe '#conference_2_to_430' do
            it { expect(form_fields.conference_2_to_430).to eq('F[0].#subform[2].TIME2TO430PM[0]') }
          end

          describe '#rep_name_and_phone_number' do
            it do
              expect(form_fields.rep_name_and_phone_number)
                .to eq('F[0].#subform[2].REPRESENTATIVENAMEANDTELEPHONENUMBER[0]')
            end
          end

          describe '#signature' do
            it { expect(form_fields.signature).to eq('F[0].#subform[3].SIGNATUREOFVETERANORCLAIMANT[0]') }
          end

          describe '#date_signed' do
            it { expect(form_fields.date_signed).to eq('F[0].#subform[3].DateSigned[0]') }
          end

          describe '#contestable_issue_fields_array' do
            it do
              expect(form_fields.contestable_issue_fields_array)
                .to eq(
                  [
                    'F[0].#subform[3].SPECIFICISSUE1[1]',
                    'F[0].#subform[3].SPECIFICISSUE1[0]',
                    'F[0].#subform[3].SPECIFICISSUE3[0]',
                    'F[0].#subform[3].SPECIFICISSUE4[0]',
                    'F[0].#subform[3].SPECIFICISSUE5[0]',
                    'F[0].#subform[3].SPECIFICISSUE6[0]'
                  ]
                )
            end
          end

          describe '#issue_decision_date_fields_array' do
            it do
              expect(form_fields.issue_decision_date_fields_array)
                .to eq(
                  [
                    'F[0].#subform[3].DateofDecision[5]',
                    'F[0].#subform[3].DateofDecision[0]',
                    'F[0].#subform[3].DateofDecision[1]',
                    'F[0].#subform[3].DateofDecision[2]',
                    'F[0].#subform[3].DateofDecision[3]',
                    'F[0].#subform[3].DateofDecision[4]'
                  ]
                )
            end
          end
        end
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
