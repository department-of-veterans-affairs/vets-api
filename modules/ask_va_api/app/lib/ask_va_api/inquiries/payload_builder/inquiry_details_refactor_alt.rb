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
          # Each class returns the inquiry details hash
          if education_benefits? || general_question?
            PayloadBuilder::GeneralInquiry.new(inquiry_params)
          elsif for_myself_as_veteran?
            PayloadBuilder::MyselfVeteran.new(inquiry_params)
          elsif for_myself_as_dependent?
            PayloadBuilder::MyselfDependent.new(inquiry_params)
          elsif for_dependent_as_veteran?
            PayloadBuilder::DependentVeteran.new(inquiry_params)
          elsif for_veteran_as_dependent?
            PayloadBuilder::VeteranDependent.new(inquiry_params)
          elsif for_dependent_as_dependent?
            PayloadBuilder::DependentDependent.new(inquiry_params)
          elsif for_veteran_as_other?
            PayloadBuilder::VeteranOther.new(inquiry_params)
          end
        end

        private

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
