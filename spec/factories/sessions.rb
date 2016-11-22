# frozen_string_literal: true
FactoryGirl.define do
  factory :session, class: Session do
    uuid  '11d21c9bf46642509aba20c4a5d5306d'

    factory :loa1_session do
      token 'a-EKsT-sBZZC1Zt6XiSLn7hp2Mb5p9G2b8rPrtzy'
      level LOA::ONE
    end

    factory :loa3_session do
      token 'rJuxrfwURpVgrN_yNVU8DqDgeCBKwFRQNiLVMJjs'
      level LOA::THREE
    end
  end
end