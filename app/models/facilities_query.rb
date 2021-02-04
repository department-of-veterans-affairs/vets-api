# frozen_string_literal: true

module FacilitiesQuery
  # When given more than one type of distance query param,
  # return nil because the app will not choose preference for the user.
  # In the controller, this logic is somewhat duplicated
  # and will render an error when given multiple params.
  # In the case that only one of these types is given,
  # return the class used to make that type of query.
  def self.generate_query(params)
    location_keys = (%i[lat long state zip bbox] & params.keys.map(&:to_sym))

    case location_keys
    when %i[lat long]
      RadialQuery.new(params)
    when [:state]
      StateQuery.new(params)
    when [:zip]
      ZipQuery.new(params)
    when [:bbox]
      BoundingBoxQuery.new(params)
    else
      params[:ids].present? ? IdsQuery.new(params) : Base.new(params)
    end
  end
end
