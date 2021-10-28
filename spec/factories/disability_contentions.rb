# frozen_string_literal: true

FactoryBot.define do
  factory :disability_contention_arrhythmia, class: 'DisabilityContention' do
    code { 450 }
    medical_term { 'arrhythmia' }
    lay_term { 'irregular heart beat' }
  end
  factory :disability_contention_arteriosclerosis, class: 'DisabilityContention' do
    code { 460 }
    medical_term { 'arteriosclerosis' }
    lay_term { 'hardened arteries' }
  end
  factory :disability_contention_arthritis, class: 'DisabilityContention' do
    code { 490 }
    medical_term { 'arthritis' }
    lay_term { 'joint stiffness and pain' }
  end
end
