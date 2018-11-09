require "test_helper"
require 'date'

describe RentalsController do
  let(:rental) {
   { customer_id: 859843310,
     movie_id: 400453147
   }
  }

  it 'zomg, a success message!' do
    get zomg_path, as: :json
    value(response).must_be :successful?
    expect(JSON.parse(response.body)["message"]).must_equal "it works"
  end

  it 'can list all overdue rentals that are currently checked out' do
    get overdue_path, as: :json
        # success response
    value(response).must_be :successful?
    fields = %w(movie_id customer_id checkout_date due_date movie customer)
    body = JSON.parse(response.body)
        # returns JSON of expected fields, sort fields
    body.each do |rental|
      expect(rental.keys.sort).must_equal fields.sort
    end
      # count in array is ovedue rentals without checkin date
    overdue_rentals = Rental.where(checkin_date: nil).where("rentals.due_date < ?", Date.current)
    expect(overdue_rentals.count).must_equal 3
    expect(body.count).must_equal 3

    # SJL: maybe: also check nested hashes
  end

  it 'can list zero rentals if there are no overdue rentals currently checked out' do
    Rental.destroy_all
    get overdue_path, as: :json
    value(response).must_be :successful?
    body = JSON.parse(response.body)
    body = []
  end

  it 'can checkout a movie' do
   # POST /rentals/check_out
   fields = %w(id movie_id customer_id due_date checkout_date checkin_date).sort
   movie_inv_avail_start = Movie.find(400453147).inventory_available
   expect do
     post check_out_path, params: rental, as: :json
   end.must_change 'Rental.count', 1

   movie_inv_avail_end = Movie.find(400453147).inventory_available
   value(response).must_be :successful?

   expect(response.header['Content-Type']).must_include 'json'
   body = JSON.parse(response.body)

   expect(body.keys.sort).must_equal fields
   expect(body["checkout_date"]).must_equal Date.current.to_s
   expect(body["checkin_date"]).must_be_nil
   expect(body["due_date"]).must_equal (Date.current + 7).to_s
   expect(movie_inv_avail_end).must_equal movie_inv_avail_start - 1
  end

  it 'can checkin a movie' do
   # post '/rentals/check_in'
   fields = %w(id movie_id customer_id due_date checkout_date checkin_date).sort
   post check_out_path, params: rental
   movie_inv_avail_start = Movie.find(400453147).inventory_available

   expect do
     post check_in_path, params: rental, as: :json
   end.wont_change 'Rental.count'

   movie_inv_avail_end = Movie.find(400453147).inventory_available
   value(response).must_be :successful?

   expect(response.header['Content-Type']).must_include 'json'
   body = JSON.parse(response.body)

   expect(body.keys.sort).must_equal fields
   expect(body["checkin_date"]).must_equal Date.current.to_s
   expect(movie_inv_avail_end).must_equal movie_inv_avail_start + 1
  end

  describe 'Checkin and Checkout' do
    let (:customer) { customers(:customer_out)}
    let (:movie) { movies(:movie_in)}
    let(:new_rental_params) {
     { customer_id: customer.id,
       movie_id: movie.id
     }
    }
    it 'checking OUT a movie increases customer mcoc count by one' do

      # START
      get customers_path, as: :json
      body = JSON.parse(response.body) # array of all customers
      body = body.select {|cust| cust["id"] == customer.id} # array of a single customer hash
      mcoc_start = body[0]["movies_checked_out_count"]
      expect(mcoc_start).must_equal 3 # just to be sure of our fixtures

      # CHECKOUT
      post check_out_path, params: new_rental_params, as: :json
      value(response).must_be :successful?

      # END
      get customers_path, as: :json
      body2 = JSON.parse(response.body) # array of all customers
      body2 = body2.select {|cust| cust["id"] == customer.id} # array of a single customer hash
      mcoc_end = body2[0]["movies_checked_out_count"]
      expect(mcoc_end).must_equal 4 # FAIL: expect 4, actual 0
    end

    it 'checking IN a movie decreases customer mcoc count by one' do
      ################################################
      # SJL: This should be an exact copy of the check-in test from the check-out test below.
      ################################################
      # ZERO
      get customers_path, as: :json
      value(response).must_be :successful?
      body = JSON.parse(response.body) # array of all customers
      body = body.select {|cust| cust["id"] == customer.id} # array of a single customer hash
      mcoc_zero = body[0]["movies_checked_out_count"]
      expect(mcoc_zero).must_equal 3 # from fixtures
      expect(Rental.count).must_equal 9

      # CHECK OUT
      post check_out_path, params: new_rental_params, as: :json
      value(response).must_be :successful?
      expect(Rental.count).must_equal 10

      # BEFORE
      get customers_path, as: :json
      value(response).must_be :successful?
      body2 = JSON.parse(response.body) # array of all customers
      body2 = body2.select {|cust| cust["id"] == customer.id}
      mcoc_before = body2[0]["movies_checked_out_count"]
      expect(mcoc_before).must_equal 4 # mcoc_zero + 1

      # CHECK IN
      post check_in_path, params: new_rental_params, as: :json
      value(response).must_be :successful?
      expect(Rental.count).must_equal 10

      # AFTER
      get customers_path, as: :json
      value(response).must_be :successful?
      body3 = JSON.parse(response.body) # array of all customers
      body3 = body3.select {|cust| cust["id"] == customer.id}
      mcoc_end = body3[0]["movies_checked_out_count"]
      expect(mcoc_end).must_equal 3 #mcoc_zero


      ################################################
      # SJL: REPEAT TEST A SECOND TIME to make sure the correct rental
      # is retrieved from an array of rentals.
      ################################################

      # ZERO
      get customers_path, as: :json
      value(response).must_be :successful?
      body = JSON.parse(response.body) # array of all customers
      body = body.select {|cust| cust["id"] == customer.id} # array of a single customer hash
      mcoc_zero = body[0]["movies_checked_out_count"]
      expect(mcoc_zero).must_equal 3 # from fixtures
      expect(Rental.count).must_equal 10

      # CHECK OUT
      post check_out_path, params: new_rental_params, as: :json
      value(response).must_be :successful?
      expect(Rental.count).must_equal 11

      # BEFORE
      get customers_path, as: :json
      value(response).must_be :successful?
      body2 = JSON.parse(response.body) # array of all customers
      body2 = body2.select {|cust| cust["id"] == customer.id}
      mcoc_before = body2[0]["movies_checked_out_count"]
      expect(mcoc_before).must_equal 4 # mcoc_zero + 1

      # CHECK IN
      post check_in_path, params: new_rental_params, as: :json
      value(response).must_be :successful?

      # AFTER
      get customers_path, as: :json
      value(response).must_be :successful?
      body3 = JSON.parse(response.body) # array of all customers
      body3 = body3.select {|cust| cust["id"] == customer.id}
      mcoc_end = body3[0]["movies_checked_out_count"]
      expect(Rental.count).must_equal 11
      expect(mcoc_end).must_equal 3 #mcoc_zero # FAIL: expect 3, actual 4
    end
  end

  describe 'get query params' do
    let (:new_rental) { Rental.new(customer: customer_overdue_test,
                                  movie: movie_out3
                      }
    describe 'sorter' do
      it 'given a single valid sorter, it sorts Overdue Rentals in ascending order' do
        # valid: title, name, checkout_date and due_date

        # path = '/movies?sort=title'
        # get path, as: :json
        # body = JSON.parse(response.body)
        # expect(body.last["title"]).must_equal "CATTACA"
      end

      it 'defaults to id: :asc if the query is nil or an empty string' do
        # new_movie.save!
        # path = '/movies'
        # query_string = ["", "?sort=", "?", "sort="]
        # query_string.each do |query|
        #    path << query
        #    get path, as: :json
        #    body = JSON.parse(response.body)
        #    expect(body.first["title"]).must_equal "movie_first"
        end
      end

      it 'will throw out invalid sorters and default to id' do
        # new_movie.save!
        # path = '/movies?sort='
        # query_string = ["bubble tea", "bubbletea", "overview", "inventory", "inventory_available"]
        # query_string.each do |query|
        #    path << query
        #    get path, as: :json
        #    body = JSON.parse(response.body)
        #    expect(body.first["title"]).must_equal "movie_first"
        #  end
      end

      it 'given >1 valid sorters, it applies sorters left to right' do
        # path = '/movies?sort=release_date&sort=title'
        # get path, as: :json
        # body = JSON.parse(response.body)
        # expect(body[0]["title"]).must_equal "Bend It Like It Like That"
        # expect(body[1]["title"]).must_equal "CATTACA"
      end
    end
  end
end
