 # frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/Va1010cg'
require_relative '../../../support/form1010cg_helpers/build_claim_data_for'

describe PdfFill::Forms::Va1010cg do
  include Form1010cgHelpers

  let(:form_subjects) { ['veteran', 'primaryCaregiver', 'secondaryCaregiverOne', 'secondaryCaregiverTwo'] }

  describe 'PDF_INPUT_LOCATIONS' do
  end

  describe 'KEY' do
  end

  describe '#merge_fields' do
    context 'certification' do
      let(:valid_example_certs_for) {
        {
          veteran: ['information-is-correct-and-true', 'consent-to-caregivers-to-perform-care'],
          primaryCaregiver: [
            'information-is-correct-and-true',
            'at-least-18-years-of-age',
            'member-of-veterans-family',
            'agree-to-perform-services--as-primary',
            'understand-revocable-status--as-primary',
            'have-understanding-of-non-employment-relationship',
          ],
          secondaryCaregiverOne: [
            'information-is-correct-and-true',
            'at-least-18-years-of-age',
            'not-member-of-veterans-family',
            'currently-or-will-reside-with-veteran--as-secondary',
            'agree-to-perform-services--as-secondary',
            'understand-revocable-status--as-secondary',
            'have-understanding-of-non-employment-relationship',
          ],
          secondaryCaregiverTwo: [
            'information-is-correct-and-true',
            'at-least-18-years-of-age',
            'member-of-veterans-family',
            'agree-to-perform-services--as-secondary',
            'understand-revocable-status--as-secondary',
            'have-understanding-of-non-employment-relationship',
          ]
        #   primaryCaregiver: {
        #     asFamilyMember: [
        #       'information-is-correct-and-true',
        #       'at-least-18-years-of-age',
        #       'member-of-veterans-family',
        #       'agree-to-perform-services--as-primary',
        #       'understand-revocable-status--as-primary',
        #       'have-understanding-of-non-employment-relationship',
        #     ],
        #     asNonFamilyMember: [
        #       'information-is-correct-and-true',
        #       'at-least-18-years-of-age',
        #       'not-member-of-veterans-family',
        #       'currently-or-will-reside-with-veteran--as-primary',
        #       'agree-to-perform-services--as-primary',
        #       'understand-revocable-status--as-primary',
        #       'have-understanding-of-non-employment-relationship',
        #     ]
        #   }
        #   secondaryCaregiver: {
        #     asFamilyMember: [
        #       'information-is-correct-and-true',
        #       'at-least-18-years-of-age',
        #       'member-of-veterans-family',
        #       'agree-to-perform-services--as-secondary',
        #       'understand-revocable-status--as-secondary',
        #       'have-understanding-of-non-employment-relationship',
        #     ],
        #     asNonFamilyMember: [
        #       'information-is-correct-and-true',
        #       'at-least-18-years-of-age',
        #       'not-member-of-veterans-family',
        #       'currently-or-will-reside-with-veteran--as-secondary',
        #       'agree-to-perform-services--as-secondary',
        #       'understand-revocable-status--as-secondary',
        #       'have-understanding-of-non-employment-relationship',
        #     ]
        #   }
        }
        let(:add_valid_certifications) { ->(data, form_subject) { data['certifications'] = valid_example_certs_for[form_subject.to_sym] } }
      }

      context 'if option :sign is false' do
        it 'does not add data to helpers' do
          form_data = {
            veteran:                build_claim_data_for( :veteran,                &add_valid_certifications  ),
            primaryCaregiver:       build_claim_data_for( :primaryCaregiver,       &add_valid_certifications  ),
            secondaryCaregiverOne:  build_claim_data_for( :secondaryCaregiverOne,  &add_valid_certifications  ),
            secondaryCaregiverTwo:  build_claim_data_for( :secondaryCaregiverTwo,  &add_valid_certifications  )
          }

          fill_options = { sign: false }

          filler_fields = described_class.new(form_data).merge_fields(fill_options)

          form_subjects.each do |form_subject|
            expect(filler_fields['helpers'][form_subject]['certifications']).to eq(nil)
          end
        end
      end

      context 'if option :sign is true' do
        context 'and no certifications are present' do
          it 'does not add data to helpers' do
            form_data = {
              veteran:                build_claim_data_for( :veteran                ),
              primaryCaregiver:       build_claim_data_for( :primaryCaregiver       ),
              secondaryCaregiverOne:  build_claim_data_for( :secondaryCaregiverOne  ),
              secondaryCaregiverTwo:  build_claim_data_for( :secondaryCaregiverTwo  )
            }

            fill_options = { sign: true }

            filler_fields = described_class.new(form_data).merge_fields(fill_options)

            form_subjects.each do |form_subject|
              expect(filler_fields['helpers'][form_subject]['certifications']).to eq(nil)
            end
          end
        end

        context 'and valid certifications are provided' do
          context 'for veteran' do
            it 'sets the "helpers"."veteran"."certify" to true' do
            end
          end

          context 'for primaryCaregiver' do
            context 'when family member' do
            end

            context 'when non family member' do
            end
          end

          context 'for secondaryCaregiverOne' do
            context 'when family member' do
            end

            context 'when non family member' do
            end
          end

          context 'for secondaryCaregiverTwo' do
            context 'when family member' do
            end

            context 'when non family member' do
            end
          end
        end
      end
    end
  end
end
