# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::PayloadBuilder::InquiryDetails do
  describe '#private methods' do
    describe '#determine_inquiry_details' do
      subject(:builder) { described_class.new(params) }

      let(:select_category) { nil }
      let(:select_topic) { nil }
      let(:your_role) { nil }
      let(:who_is_your_question_about) { nil }
      let(:relationship_to_veteran) { nil }
      let(:more_about_your_relationship_to_veteran) { nil }
      let(:about_your_relationship_to_family_member) { nil }
      let(:is_question_about_veteran_or_someone_else) { nil }
      let(:their_relationship_to_veteran) { nil }
      let(:params) do
        {
          select_category:,
          select_topic:,
          your_role:,
          who_is_your_question_about:,
          relationship_to_veteran:,
          more_about_your_relationship_to_veteran:,
          about_your_relationship_to_family_member:,
          is_question_about_veteran_or_someone_else:,
          their_relationship_to_veteran:
        }
      end
      let(:general_question_result) do
        {
          inquiry_about: 'A general question',
          dependent_relationship: nil,
          veteran_relationship: nil,
          level_of_authentication: 'Personal'
        }
      end
      let(:about_me_veteran_result) do
        {
          inquiry_about: 'About Me, the Veteran',
          dependent_relationship: nil,
          veteran_relationship: nil,
          level_of_authentication: 'Personal'
        }
      end

      context 'when category is education and topic is NOT VRE' do
        let(:select_category) { 'Education benefits and work study' }
        let(:select_topic) { 'NOT VRE' }
        let(:who_is_your_question_about) { 'Myself' }

        it 'returns the correct info' do
          expect(builder.call)
            .to eq(general_question_result)
        end
      end

      context 'when category is benefits outside us and topic edu' do
        let(:select_category) { 'Benefits issues outside the U.S.' }
        let(:select_topic) { 'Education benefits and work study' }
        let(:who_is_your_question_about) { 'Myself' }

        it 'returns the correct info' do
          expect(builder.call)
            .to eq(general_question_result)
        end
      end

      context 'when who_is_your_question_about is a general question' do
        let(:select_category) { 'Benefits issues outside the U.S.' }
        let(:select_topic) { 'Education benefits and work study' }
        let(:who_is_your_question_about) { "It's a general question" }

        it 'returns the correct info' do
          expect(builder.call)
            .to eq(general_question_result)
        end
      end

      context 'when the veteran is the submitter' do
        let(:select_category) { 'Healthcare' }
        let(:select_topic) { 'Audiology and Hearing Aids' }
        let(:who_is_your_question_about) { 'Myself' }
        let(:relationship_to_veteran) { "I'm the Veteran" }

        it 'returns a payload structure to CRM API' do
          expect(builder.call)
            .to eq(about_me_veteran_result)
        end

        context 'when who_is_your_question_about is nil' do
          let(:who_is_your_question_about) { nil }

          it 'returns a payload structure to CRM API' do
            expect(builder.call)
              .to eq(about_me_veteran_result)
          end
        end
      end

      context 'when the dependent is the submitter' do
        let(:select_category) { 'Healthcare' }
        let(:select_topic) { 'Audiology and Hearing Aids' }
        let(:who_is_your_question_about) { 'Myself' }
        let(:relationship_to_veteran) { "I'm a family member of a Veteran" }
        let(:more_about_your_relationship_to_veteran) { "I'm the Veteran's Child" }

        it 'returns a payload structure to CRM API' do
          expect(builder.call)
            .to eq({
                     inquiry_about: 'For the dependent of a Veteran',
                     dependent_relationship: nil,
                     veteran_relationship: more_about_your_relationship_to_veteran,
                     level_of_authentication: 'Personal'
                   })
        end
      end

      context 'when the Veteran is asking for a dependent' do
        let(:select_category) { 'Healthcare' }
        let(:select_topic) { 'Audiology and Hearing Aids' }
        let(:who_is_your_question_about) { 'Someone else' }
        let(:relationship_to_veteran) { "I'm the Veteran" }
        let(:about_your_relationship_to_family_member) { "They're my child" }

        it 'returns a payload structure to CRM API' do
          expect(builder.call)
            .to eq({
                     inquiry_about: 'For the dependent of a Veteran',
                     dependent_relationship: about_your_relationship_to_family_member,
                     veteran_relationship: nil,
                     level_of_authentication: 'Personal'
                   })
        end
      end

      context 'when the submitter is a family member of the Veteran' do
        let(:select_category) { 'Healthcare' }
        let(:select_topic) { 'Audiology and Hearing Aids' }
        let(:who_is_your_question_about) { 'Someone else' }
        let(:relationship_to_veteran) { "I'm a family member of a Veteran" }
        let(:is_question_about_veteran_or_someone_else) { 'Veteran' }
        let(:more_about_your_relationship_to_veteran) { "I'm the Veteran's child" }

        it 'returns a payload structure to CRM API' do
          expect(builder.call)
            .to eq({
                     inquiry_about: 'On Behalf of a Veteran',
                     dependent_relationship: nil,
                     veteran_relationship: more_about_your_relationship_to_veteran,
                     level_of_authentication: 'Personal'
                   })
        end
      end

      context 'when family member asking about a dependent of a Veteran' do
        let(:select_category) { 'Healthcare' }
        let(:select_topic) { 'Audiology and Hearing Aids' }
        let(:who_is_your_question_about) { 'Someone else' }
        let(:relationship_to_veteran) { "I'm a family member of a Veteran" }
        let(:is_question_about_veteran_or_someone_else) { 'Someone else' }
        let(:their_relationship_to_veteran) { 'CHILD' }

        it 'returns a payload structure to CRM API' do
          expect(builder.call)
            .to eq({
                     inquiry_about: 'For the dependent of a Veteran',
                     dependent_relationship: their_relationship_to_veteran,
                     veteran_relationship: nil,
                     level_of_authentication: 'Personal'
                   })
        end
      end

      context 'when level of authentication is business' do
        let(:select_category) { 'Healthcare' }
        let(:select_topic) { 'Audiology and Hearing Aids' }
        let(:who_is_your_question_about) { 'Someone else' }
        let(:relationship_to_veteran) do
          "I'm connected to the Veteran through my work (for example, as a School Certifying Official or fiduciary)"
        end
        let(:your_role) { 'Fiduciary' }

        it 'returns a payload structure to CRM API' do
          expect(builder.call)
            .to eq({
                     inquiry_about: 'On Behalf of a Veteran',
                     dependent_relationship: nil,
                     veteran_relationship: your_role,
                     level_of_authentication: 'Business'
                   })
        end
      end
    end
  end
end
