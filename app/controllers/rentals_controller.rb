class RentalsController < ApplicationController  
  #### `GET /zomg`
  def zomg
    render json: {message: "it_works"}
  end

  #### `POST /rentals/check-out`
  # Check out one of the movie's inventory to the customer. The rental's check-out date should be set to today, and the due date should be set to a week from today.
  #
  # **Note:** Some of the fields from wave 2 should now have interesting values. Good thing you wrote tests for them, right... right?
  #
  # Request body:
  #
  # | Field         | Datatype            | Description
  # |---------------|---------------------|------------
  # | `customer_id` | integer             | ID of the customer checking out this film
  # | `movie_id`    | integer | ID of the movie to be checked out
  def check_out
    @rental = Rental.new(rental_params)
    unless @rental.checkout_data && @rental.save
      render json: {ok: false, cause: "validation errors", errors: @rental.errors}, status: :bad_request
    end
  end

  #### `POST /rentals/check-in`
  # Check in one of a customer's rentals
  #
  # Request body:
  #
  # | Field         | Datatype | Description
  # |---------------|----------|------------
  # | `customer_id` | integer  | ID of the customer checking in this film
  # | `movie_id`    | integer | ID of the movie to be checked in
  def check_in
    @rental = Rental.find_by(movie_id: params[:movie_id], customer_id: params[:customer_id])
    unless @rental.checkin_data && @rental.save
      render json: {ok: false, cause: "validation errors", errors: @rental.errors}, status: :bad_request
    end

  end

  private

  def rental_params
     return params.permit(:customer_id, :movie_id)
  end

end
