# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/ModuleLength
module AppealsApi
  module PdfConstruction
    module HigherLevelReview
      module V1
        describe FormData do
          let(:higher_level_review) { build(:higher_level_review) }
          let(:form_data) { described_class.new(higher_level_review) }

          context 'delegation' do
            describe '#first_name' do
              it do
                expect(higher_level_review).to receive(:first_name)
                form_data.first_name
              end
            end

            describe '#middle_initial' do
              it do
                expect(higher_level_review).to receive(:middle_initial)
                form_data.middle_initial
              end
            end

            describe '#last_name' do
              it do
                expect(higher_level_review).to receive(:last_name)
                form_data.last_name
              end
            end

            describe '#file_number' do
              it do
                expect(higher_level_review).to receive(:file_number)
                form_data.file_number
              end
            end

            describe '#service_number' do
              it do
                expect(higher_level_review).to receive(:service_number)
                form_data.service_number
              end
            end

            describe '#insurance_policy_number' do
              it do
                expect(higher_level_review).to receive(:insurance_policy_number)
                form_data.insurance_policy_number
              end
            end

            describe '#date_signed' do
              it do
                expect(higher_level_review).to receive(:date_signed)
                form_data.date_signed
              end
            end

            describe '#contestable_issues' do
              it do
                expect(higher_level_review).to receive(:contestable_issues)
                form_data.contestable_issues
              end
            end

            describe '#birth_mm' do
              it do
                expect(higher_level_review).to receive(:birth_mm)
                form_data.birth_month
              end
            end

            describe '#birth_dd' do
              it do
                expect(higher_level_review).to receive(:birth_dd)
                form_data.birth_day
              end
            end

            describe '#birth_yyyy' do
              it do
                expect(higher_level_review).to receive(:birth_yyyy)
                form_data.birth_year
              end
            end
          end

          context 'ssn' do
            describe '#first_three_ssn' do
              it { expect(form_data.first_three_ssn).to eq('123') }
            end

            describe '#second_two_ssn' do
              it { expect(form_data.second_two_ssn).to eq('45') }
            end

            describe '#last_four_ssn' do
              it { expect(form_data.last_four_ssn).to eq('6789') }
            end
          end

          describe '#claimant_type' do
            it "returns off if it's not 4" do
              expect(form_data.claimant_type(3)).to eq('off')
            end

            it 'returns 1 if it is 4' do
              expect(form_data.claimant_type(4)).to eq(1)
            end
          end

          context 'mailing address' do
            describe '#mailing_address_street' do
              it { expect(form_data.mailing_address_street).to eq('USE ADDRESS ON FILE') }
            end

            describe '#mailing_address_unit_number' do
              it { expect(form_data.mailing_address_unit_number).to eq('') }
            end

            describe '#mailing_address_city' do
              it { expect(form_data.mailing_address_city).to eq('') }
            end

            describe '#mailing_address_state' do
              it { expect(form_data.mailing_address_state).to eq('') }
            end

            describe '#mailing_address_country' do
              it { expect(form_data.mailing_address_country).to eq('') }
            end

            describe '#mailing_address_zip_first_5' do
              it { expect(form_data.mailing_address_zip_first_5).to eq('') }
            end

            describe '#mailing_address_zip_last_4' do
              it { expect(form_data.mailing_address_zip_last_4).to eq('') }
            end
          end

          describe '#veteran_phone_number' do
            context 'when there is a phone number' do
              it 'returns the number' do
                expect(form_data.veteran_phone_number).to eq('+34-555-800-1111 ex2')
              end
            end

            context 'when there is no phone number' do
              it do
                allow(higher_level_review).to receive(:veteran_phone_number).and_return('')
                expect(form_data.veteran_phone_number).to eq('USE PHONE ON FILE')
              end
            end
          end

          describe '#veteran_email' do
            context 'when there is an email' do
              it 'returns the email' do
                expect(form_data.veteran_email).to eq('josie@example.com')
              end
            end

            context 'when there is no email' do
              it do
                allow(higher_level_review).to receive(:email).and_return('')
                expect(form_data.veteran_email).to eq('USE EMAIL ON FILE')
              end
            end
          end

          describe '#benefit_type' do
            it "returns Off when the benefit_type provided doesn't match the HLR" do
              expect(form_data.benefit_type('education')).to eq('Off')
            end

            it 'returns the correct form code for the matching benefit type' do
              expect(form_data.benefit_type('compensation')).to eq(1)
            end
          end

          describe '#same_office' do
            context 'when true' do
              it do
                expect(form_data.same_office).to eq(1)
              end
            end

            context 'when false' do
              it do
                allow(higher_level_review).to receive(:same_office).and_return(false)
                expect(form_data.same_office).to eq('Off')
              end
            end
          end

          describe '#informal_conference' do
            context 'when true' do
              it do
                expect(form_data.informal_conference).to eq(1)
              end
            end

            context 'when false' do
              it do
                allow(higher_level_review).to receive(:informal_conference).and_return(false)
                expect(form_data.informal_conference).to eq('Off')
              end
            end
          end

          describe '#informal_conference_times' do
            context 'when included' do
              it do
                expect(form_data.informal_conference_times('1230-1400 ET')).to eq(1)
              end
            end

            context 'when not included' do
              it do
                expect(form_data.informal_conference_times('800-1000 ET')).to eq('Off')
              end
            end
          end

          describe 'rep_name_and_phone_number' do
            it { expect(form_data.rep_name_and_phone_number).to eq('Helen Holly +6-555-800-1111 ext2') }
          end

          describe '#signature' do
            it { expect(form_data.signature).to eq('Jane Z Doe') }
          end
        end
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
