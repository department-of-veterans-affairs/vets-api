# frozen_string_literal: true

module AskVAApi
  module Inquiries
    module PayloadBuilder
      class InquiryDetails
        attr_reader :inquiry_params

        def initialize(inquiry_params)
          @inquiry_params = inquiry_params
        end

        def call
          {
            inquiry_about: inquiry_about || 'Unknown inquiry type',
            dependent_relationship: dependent_relationship || nil,
            veteran_relationship: veteran_relationship || nil,
            level_of_authentication: level_of_authentication || (role ? 'Business' : 'Personal')
          }
        end

        private

        def inquiry_about
          if education_benefits? || inquiry_params[:who_is_your_question_about] == "It's a general question"
            'A general question'
          elsif inquiry_params[:who_is_your_question_about] == 'Myself' || inquiry_params[:who_is_your_question_about].nil?
            if inquiry_params[:relationship_to_veteran] == "I'm the Veteran"
              'About Me, the Veteran'
            elsif inquiry_params[:relationship_to_veteran] == "I'm a family member of a Veteran" && inquiry_params[:more_about_your_relationship_to_veteran]
              'For the dependent of a Veteran'
            end
          elsif inquiry_params[:who_is_your_question_about] == 'Someone else' || inquiry_params[:your_role]
            if inquiry_params[:relationship_to_veteran] == "I'm the Veteran" && inquiry_params[:about_your_relationship_to_family_member]
              'For the dependent of a Veteran'
            elsif inquiry_params[:relationship_to_veteran] == "I'm a family member of a Veteran"
              if inquiry_params[:is_question_about_veteran_or_someone_else] == 'Veteran' && inquiry_params[:more_about_your_relationship_to_veteran]
                'On Behalf of a Veteran'
              elsif inquiry_params[:is_question_about_veteran_or_someone_else] == 'Someone else' && inquiry_params[:their_relationship_to_veteran]
                'For the dependent of a Veteran'
              end
            elsif inquiry_params[:your_role]
              'On Behalf of a Veteran'
            end
          end
        end

        def dependent_relationship
          if education_benefits? || inquiry_params[:who_is_your_question_about] == "It's a general question"
            nil
          elsif inquiry_params[:who_is_your_question_about] == 'Myself' || inquiry_params[:who_is_your_question_about].nil?
            if inquiry_params[:relationship_to_veteran] == "I'm the Veteran"
              nil
            elsif inquiry_params[:relationship_to_veteran] == "I'm a family member of a Veteran" && inquiry_params[:more_about_your_relationship_to_veteran]
              nil
            end
          elsif inquiry_params[:who_is_your_question_about] == 'Someone else' || inquiry_params[:your_role]
            if inquiry_params[:relationship_to_veteran] == "I'm the Veteran" && inquiry_params[:about_your_relationship_to_family_member]
              inquiry_params[:about_your_relationship_to_family_member]
            elsif inquiry_params[:relationship_to_veteran] == "I'm a family member of a Veteran"
              if inquiry_params[:is_question_about_veteran_or_someone_else] == 'Veteran' && inquiry_params[:more_about_your_relationship_to_veteran]
                nil
              elsif inquiry_params[:is_question_about_veteran_or_someone_else] == 'Someone else' && inquiry_params[:their_relationship_to_veteran]
                inquiry_params[:their_relationship_to_veteran]
              end
            elsif inquiry_params[:your_role]
              nil
            end
          end
        end

        def veteran_relationship
          if education_benefits? || inquiry_params[:who_is_your_question_about] == "It's a general question"
            inquiry_params[:your_role]
          elsif inquiry_params[:who_is_your_question_about] == 'Myself' || inquiry_params[:who_is_your_question_about].nil?
            if inquiry_params[:relationship_to_veteran] == "I'm the Veteran"
              nil
            elsif inquiry_params[:relationship_to_veteran] == "I'm a family member of a Veteran" && inquiry_params[:more_about_your_relationship_to_veteran]
              inquiry_params[:more_about_your_relationship_to_veteran]
            end
          elsif inquiry_params[:who_is_your_question_about] == 'Someone else' || inquiry_params[:your_role]
            if inquiry_params[:relationship_to_veteran] == "I'm the Veteran" && inquiry_params[:about_your_relationship_to_family_member]
              nil
            elsif inquiry_params[:relationship_to_veteran] == "I'm a family member of a Veteran"
              if inquiry_params[:is_question_about_veteran_or_someone_else] == 'Veteran' && inquiry_params[:more_about_your_relationship_to_veteran]
                inquiry_params[:more_about_your_relationship_to_veteran]
              elsif inquiry_params[:is_question_about_veteran_or_someone_else] == 'Someone else' && inquiry_params[:their_relationship_to_veteran]
                nil
              end
            elsif inquiry_params[:your_role]
              inquiry_params[:your_role]
            end
          end
        end

        def level_of_authentication
          if education_benefits? || inquiry_params[:who_is_your_question_about] == "It's a general question"
            role ? 'Business' : 'Personal'
          elsif inquiry_params[:who_is_your_question_about] == 'Myself' || inquiry_params[:who_is_your_question_about].nil?
            if inquiry_params[:relationship_to_veteran] == "I'm the Veteran"
              role ? 'Business' : 'Personal'
            elsif inquiry_params[:relationship_to_veteran] == "I'm a family member of a Veteran" && inquiry_params[:more_about_your_relationship_to_veteran]
              role ? 'Business' : 'Personal'
            end
          elsif inquiry_params[:who_is_your_question_about] == 'Someone else' || inquiry_params[:your_role]
            if inquiry_params[:relationship_to_veteran] == "I'm the Veteran" && inquiry_params[:about_your_relationship_to_family_member]
              role ? 'Business' : 'Personal'
            elsif inquiry_params[:relationship_to_veteran] == "I'm a family member of a Veteran"
              if inquiry_params[:is_question_about_veteran_or_someone_else] == 'Veteran' && inquiry_params[:more_about_your_relationship_to_veteran]
                role ? 'Business' : 'Personal'
              elsif inquiry_params[:is_question_about_veteran_or_someone_else] == 'Someone else' && inquiry_params[:their_relationship_to_veteran]
                role ? 'Business' : 'Personal'
              end
            elsif inquiry_params[:your_role]
              'Business'
            end
          end
        end

        def role
          inquiry_params[:your_role]
        end

        def education_benefits?
          category == 'Education benefits and work study' &&
          topic != 'Veteran Readiness and Employment'
        end

        def category
          inquiry_params[:select_category]
        end

        def topic
          inquiry_params[:select_topic]
        end
      end
    end
  end
end
