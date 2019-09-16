# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength
namespace :preferences do
  desc 'Seed the database with the MVP Preference and associated PreferenceChoices'
  task initial_seed: :environment do
    tracking = {
      starting_preference_count: Preference.count,
      starting_preference_choice_count: PreferenceChoice.count,
      final_preference_count: 0,
      final_preference_choice_count: 0,
      errors: 0
    }

    begin
      preference = Preference.find_or_create_by!(code: preference_attrs[:code]) do |pref|
        pref.title = preference_attrs[:title]
      end
      tracking[:final_preference_count] += 1

      preference_choice_attrs.each do |attrs|
        PreferenceChoice.find_or_create_by!(code: attrs[:code]) do |pref_choice|
          pref_choice.description   = attrs[:description]
          pref_choice.preference_id = preference.id
        end

        tracking[:final_preference_choice_count] += 1
      end

      p tracking
    rescue => e
      tracking[:errors] += 1
      message = "While initially seeding Preferences, experienced this error: #{e}"

      p message
      Rails.logger.error message
    end
  end
end

def preference_attrs
  {
    code: 'benefits',
    title: 'the benefits a veteran is interested in, so VA.gov can help you apply for them'
  }
end

def preference_choice_attrs
  [
    {
      code: 'health-care',
      description: 'Get health care coverage'
    },
    {
      code: 'disability',
      description: 'Find benefits for an illness or injury related to a veterans service'
    },
    {
      code: 'appeals',
      description: 'Appeal the decision VA made on veterans disability claim'
    },
    {
      code: 'education-training',
      description: 'GI Bill to help pay for college, training, or certification'
    },
    {
      code: 'careers-employment',
      description: 'Find a job, build skills, or get support for my own business'
    },
    {
      code: 'pension',
      description: 'Get financial support for veterans disability or for care related to aging'
    },
    {
      code: 'housing-assistance',
      description: 'Find, buy, build, modify, or refinance a place to live'
    },
    {
      code: 'life-insurance',
      description: 'Learn about veterans life insurance options'
    },
    {
      code: 'burials-memorials',
      description: 'Apply for burial in a VA cemetery or for allowances to cover burial costs'
    },
    {
      code: 'family-caregiver-benefits',
      description: 'Learn about benefits for family members and caregivers'
    }
  ]
end
# rubocop:enable Metrics/MethodLength
