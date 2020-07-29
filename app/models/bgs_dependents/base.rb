module BGSDependents
  class Base
    def dependent_address(dependents_application, lives_with_vet, alt_address)
      return dependents_application.dig('veteran_contact_information', 'veteran_address') if lives_with_vet

      alt_address
    end
  end
end