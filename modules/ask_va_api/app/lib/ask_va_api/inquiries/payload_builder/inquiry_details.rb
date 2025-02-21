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
          inquiry_details = base_inquiry_details(inquiry_params[:your_role])

          if education_benefits_and_not_vrae(inquiry_params[:select_category],
                                             inquiry_params[:select_topic]) ||
             inquiry_params[:who_is_your_question_about] == "It's a general question" ||
             benefits_outside_us_edu(inquiry_params[:select_category],
                                     inquiry_params[:select_topic])
            return general_inquiry(inquiry_params, inquiry_details)
          end

          if inquiry_params[:who_is_your_question_about] == 'Someone else' || inquiry_params[:your_role]
            return handle_others_inquiry(inquiry_params, inquiry_details)
          end

          if inquiry_params[:who_is_your_question_about] == 'Myself' ||
             inquiry_params[:who_is_your_question_about].nil?
            handle_self_inquiry(inquiry_params, inquiry_details)
          end
        end

        private

        def education_benefits_and_not_vrae(category, topic)
          category == 'Education benefits and work study' && topic != 'Veteran Readiness and Employment (Chapter 31)'
        end

        def benefits_outside_us_edu(category, topic)
          category == 'Benefits issues outside the U.S.' && topic == 'Education benefits and work study'
        end

        def base_inquiry_details(role)
          {
            inquiry_about: 'Unknown inquiry type',
            dependent_relationship: nil,
            veteran_relationship: nil,
            level_of_authentication: role ? 'Business' : 'Personal'
          }
        end

        def build_inquiry_details(details_hash)
          details_hash[:inquiry_details]
            .merge({
                     inquiry_about: details_hash[:inquiry_about],
                     dependent_relationship: details_hash[:dependent_relationship],
                     veteran_relationship: details_hash[:veteran_relationship],
                     level_of_authentication: details_hash[:inquiry_details][:level_of_authentication] || 'Personal'
                   })
        end

        def handle_self_inquiry(inquiry_params, inquiry_details)
          if inquiry_params[:relationship_to_veteran] == "I'm the Veteran"
            build_inquiry_details(inquiry_details:, inquiry_about: 'About Me, the Veteran')
          elsif inquiry_params[:relationship_to_veteran] == "I'm a family member of a Veteran" &&
                inquiry_params[:more_about_your_relationship_to_veteran]
            build_inquiry_details(
              inquiry_details:,
              inquiry_about: 'For the dependent of a Veteran',
              veteran_relationship: inquiry_params[:more_about_your_relationship_to_veteran]
            )
          end
        end

        def handle_others_inquiry(inquiry_params, inquiry_details)
          if inquiry_params[:relationship_to_veteran] == "I'm the Veteran" &&
             inquiry_params[:about_your_relationship_to_family_member]
            build_inquiry_details(
              inquiry_details:,
              inquiry_about: 'For the dependent of a Veteran',
              dependent_relationship: inquiry_params[:about_your_relationship_to_family_member]
            )
          elsif inquiry_params[:relationship_to_veteran] == "I'm a family member of a Veteran"
            handle_family_inquiry(inquiry_params, inquiry_details)
          elsif inquiry_params[:your_role]
            build_inquiry_details(
              inquiry_details:,
              inquiry_about: 'On Behalf of a Veteran',
              veteran_relationship: inquiry_params[:your_role],
              level_of_authentication: 'Business'
            )
          end
        end

        def handle_family_inquiry(inquiry_params, inquiry_details)
          if inquiry_params[:is_question_about_veteran_or_someone_else] == 'Veteran' &&
             inquiry_params[:more_about_your_relationship_to_veteran]
            build_inquiry_details(
              inquiry_details:,
              inquiry_about: 'On Behalf of a Veteran',
              veteran_relationship: inquiry_params[:more_about_your_relationship_to_veteran]
            )
          elsif inquiry_params[:is_question_about_veteran_or_someone_else] == 'Someone else' &&
                inquiry_params[:their_relationship_to_veteran]
            build_inquiry_details(
              inquiry_details:,
              inquiry_about: 'For the dependent of a Veteran',
              dependent_relationship: inquiry_params[:their_relationship_to_veteran]
            )
          end
        end

        def general_inquiry(inquiry_params, details)
          build_inquiry_details(
            inquiry_details: details,
            inquiry_about: 'A general question',
            veteran_relationship: inquiry_params[:your_role]
          )
        end
      end
    end
  end
end
