# frozen_string_literal: true

module RepresentationManagement
  class AccreditedEntityQuery
    include ActiveModel::Model

    # Here we need to take the query string and compare it to the full names of
    # the accredited individuals and organizations in their respective tables.
    # We need to order the records by word similarity to the query string.
    # Then those records need to be passed to the seralizer to be rendered as JSON.
  end
end
