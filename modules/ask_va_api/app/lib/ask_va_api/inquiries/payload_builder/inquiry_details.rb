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
            inquiry_about:,
            dependent_relationship:,
            veteran_relationship:,
            level_of_authentication:
          }
        end

        private

        def inquiry_about
          if education_benefits? || general_question? || benefits_outside_us_edu?
            'A general question'
          elsif for_myself_as_veteran?
            'About Me, the Veteran'
          elsif for_myself_as_dependent? || for_dependent_as_veteran? || for_dependent_as_dependent?
            'For the dependent of a Veteran'
          elsif for_veteran_as_dependent? || for_veteran_as_other?
            'On Behalf of a Veteran'
          else
            'Unknown inquiry type'
          end
        end

        def dependent_relationship
          return veteran_relationship_to_family_member if for_dependent_as_veteran?
          return dependent_relationship_to_veteran if for_dependent_as_dependent?

          nil
        end

        def veteran_relationship
          if education_benefits? || general_question? || for_veteran_as_other?
            your_role
          elsif for_myself_as_dependent? || for_veteran_as_dependent?
            your_relationship_to_veteran
          end
        end

        def level_of_authentication
          if for_veteran_as_other?
            'Business'
          else
            your_role ? 'Business' : 'Personal'
          end
        end

        def for_myself_as_veteran?
          for_myself? && i_am_the_veteran?
        end

        def for_myself_as_dependent?
          for_myself? && family_to_veteran? && your_relationship_to_veteran
        end

        def for_dependent_as_veteran?
          for_others? && i_am_the_veteran? && veteran_relationship_to_family_member
        end

        def for_veteran_as_dependent?
          for_others? && family_to_veteran? && question_about_veteran? && your_relationship_to_veteran
        end

        def for_dependent_as_dependent?
          for_others? && family_to_veteran? && question_about_someone_else? && dependent_relationship_to_veteran
        end

        def for_veteran_as_other?
          for_others? && your_role
        end

        def your_role
          inquiry_params[:your_role]
        end

        def education_benefits?
          category == 'Education benefits and work study' &&
            topic != 'Veteran Readiness and Employment (Chapter 31)'
        end

        def benefits_outside_us_edu?
          category == 'Benefits issues outside the U.S.' &&
            topic == 'Education benefits and work study'
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
