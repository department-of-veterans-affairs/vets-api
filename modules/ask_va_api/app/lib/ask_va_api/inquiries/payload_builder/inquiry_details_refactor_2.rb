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
          if education_benefits? || general_question?
            'A general question'
          elsif for_myself?
            if i_am_the_veteran?
              'About Me, the Veteran'
            elsif family_to_veteran? && your_relationship_to_veteran
              'For the dependent of a Veteran'
            end
          elsif for_others?
            if i_am_the_veteran? && veteran_relationship_to_family_member
              'For the dependent of a Veteran'
            elsif family_to_veteran?
              if question_about_veteran? && your_relationship_to_veteran
                'On Behalf of a Veteran'
              elsif question_about_someone_else? && dependent_relationship_to_veteran
                'For the dependent of a Veteran'
              end
            elsif your_role
              'On Behalf of a Veteran'
            end
          end
        end

        def dependent_relationship
          if education_benefits? || general_question?
            nil
          elsif for_myself?
            if i_am_the_veteran?
              nil
            elsif family_to_veteran? && your_relationship_to_veteran
              nil
            end
          elsif for_others?
            if i_am_the_veteran? && veteran_relationship_to_family_member
              veteran_relationship_to_family_member
            elsif family_to_veteran?
              if question_about_veteran? && your_relationship_to_veteran
                nil
              elsif question_about_someone_else? && dependent_relationship_to_veteran
                dependent_relationship_to_veteran
              end
            elsif your_role
              nil
            end
          end
        end

        def veteran_relationship
          if education_benefits? || general_question?
            your_role
          elsif for_myself?
            if i_am_the_veteran?
              nil
            elsif family_to_veteran? && your_relationship_to_veteran
              your_relationship_to_veteran
            end
          elsif for_others?
            if i_am_the_veteran? && veteran_relationship_to_family_member
              nil
            elsif family_to_veteran?
              if question_about_veteran? && your_relationship_to_veteran
                your_relationship_to_veteran
              elsif question_about_someone_else? && dependent_relationship_to_veteran
                nil
              end
            elsif your_role
              your_role
            end
          end
        end

        def level_of_authentication
          if education_benefits? || general_question?
            your_role ? 'Business' : 'Personal'
          elsif for_myself?
            if i_am_the_veteran?
              your_role ? 'Business' : 'Personal'
            elsif family_to_veteran? && your_relationship_to_veteran
              your_role ? 'Business' : 'Personal'
            end
          elsif for_others?
            if i_am_the_veteran? && veteran_relationship_to_family_member
              your_role ? 'Business' : 'Personal'
            elsif family_to_veteran?
              if question_about_veteran? && your_relationship_to_veteran
                your_role ? 'Business' : 'Personal'
              elsif question_about_someone_else? && dependent_relationship_to_veteran
                your_role ? 'Business' : 'Personal'
              end
            elsif your_role
              'Business'
            end
          end
        end

        def your_role
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

        def general_question?
          inquiry_params[:who_is_your_question_about] == "It's a general question"
        end

        def for_others?
          inquiry_params[:who_is_your_question_about] == 'Someone else' || your_role
        end

        def for_myself?
          inquiry_params[:who_is_your_question_about] == 'Myself' || inquiry_params[:who_is_your_question_about].nil?
        end

        def i_am_the_veteran?
          inquiry_params[:relationship_to_veteran] == "I'm the Veteran"
        end

        def family_to_veteran?
          inquiry_params[:relationship_to_veteran] == "I'm a family member of a Veteran"
        end

        def your_relationship_to_veteran
          inquiry_params[:more_about_your_relationship_to_veteran]
        end

        def question_about_veteran?
          inquiry_params[:is_question_about_veteran_or_someone_else] == 'Veteran'
        end

        def question_about_someone_else?
          inquiry_params[:is_question_about_veteran_or_someone_else] == 'Someone else'
        end

        def veteran_relationship_to_family_member
          inquiry_params[:about_your_relationship_to_family_member]
        end

        def dependent_relationship_to_veteran
          inquiry_params[:their_relationship_to_veteran]
        end
      end
    end
  end
end
