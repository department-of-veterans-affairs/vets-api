# frozen_string_literal: true

require './modules/vba_documents/lib/deployments_helper'

# Each row corresponds to one git 'item' as returned by the json in the following query:
# https://api.github.com/search/issues?q=is:merged%20is:pr%20label:BenefitsIntake%20repo:department-of-veterans-affairs/vets-api
module VBADocuments
  class GitItems < ApplicationRecord
    GIT_URL = 'https://api.github.com/search/issues' #define GIT_QUERY,GIT_PARAMS before mixin below
    GIT_PARAMS = { q: 'is:merged is:pr label:BenefitsIntake repo:department-of-veterans-affairs/vets-api' }
    extend VBADocuments::VAForms::DeploymentsHelper #module shared between VBADocuments and VAForms

    validates_uniqueness_of :url
  end
end
# load('./modules/vba_documents/lib/deployments_helper.rb')
# load('./modules/vba_documents/app/models/vba_documents/git_items.rb')
#
# Sample query:
# https://api.github.com/search/issues?q=is:merged%20is:pr%20label:BenefitsIntake%20repo:department-of-veterans-affairs/vets-api
#
