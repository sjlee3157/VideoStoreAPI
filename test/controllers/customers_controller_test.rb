require "test_helper"

describe CustomersController do
  describe 'index action' do
    it "should get index" do
      get customers_path, as: :json
      must_respond_with :success
    end

    it 'returns expected fields' do
      fields = %w(id movies_checked_out_count name phone postal_code registered_at)
      get customers_path, as: :json
      body = JSON.parse(response.body)
      body.each do |customer|
        customer.keys.sort.must_equal fields
      end
    end
  end

  describe 'get query params' do
    let (:new_customer) { Customer.new(id: 1,
                                   name: "customer_first",
                                   registered_at: Time.zone.now,
                                   postal_code: "postal_code",
                                   phone: "phone")
                    }
    let (:new_customer2) { Customer.new(id: 2,
                                       name: "customer_first",
                                       registered_at: Time.zone.now,
                                       postal_code: "postal_code",
                                       phone: "phone")
    }

    describe 'sorter' do
      it 'given a single valid sorter, it sorts Customers in ascending order' do
        # valid: name, registered_at, and postal_code
        new_customer.save!
        path = '/customers?sort=registered_at'
        get path, as: :json
        body = JSON.parse(response.body)
        expect(body.first["name"][0]).must_equal "A"
      end

      it 'defaults to id: :asc if the query is nil or an empty string' do
        new_customer.save!
        path = '/customers'
        query_string = ["", "?sort=", "?", "sort="]
        query_string.each do |query|
           path << query
           get path, as: :json
           body = JSON.parse(response.body)
           expect(body.first["name"]).must_equal "customer_first"
        end
      end

      it 'will throw out invalid sorters and default to id' do
        new_customer.save!
        path = '/customers?sort='
        query_string = ["bubble tea", "bubbletea", "address", "phone", "id"]
        query_string.each do |query|
           path << query
           get path, as: :json
           body = JSON.parse(response.body)
           expect(body.first["name"]).must_equal "customer_first"
         end
      end

      it 'given >1 valid sorters, it applies sorters left to right' do
        path = '/customers?sort=postal_code&sort=name'
        get path, as: :json
        body = JSON.parse(response.body)
        expect(body[0]["postal_code"]).must_equal "00000"
        expect(body[1]["name"]).must_equal "Zipper Zigzag"
      end
    end

    describe 'items per page' do
      it 'returns the appropriate # of items per page "n"' do
        get '/customers?n=2', as: :json
        body = JSON.parse(response.body)
        expect(body.length).must_equal 2
      end

    end

    describe 'page number' do
      before do
        # clear customer db then create new set of 6
        Customer.destroy_all
        6.times do |i|
          Customer.create(id: i,
          name: "customer_#{i}",
          registered_at: Time.zone.now,
          postal_code: "postal_code",
          phone: "phone")
        end

      end

      it 'returns a start page if specified "p"' do
        # get 3rd page of customers at 2 per page
        # starting at id=0, the first item on page 3
        # should be id 4
        get '/customers?n=2&p=3', as: :json
        body = JSON.parse(response.body)
        # expect 2nd set of fixtures sorted by id asc order
        # use let to create 2 new customers
        expect(body.length).must_equal 2
        expect(body[0]["id"]).must_equal 4
      end
    end

    describe 'endpoints' do
      let(:rental) {
        { customer_id: Customer.first.id,
          movie_id: Movie.last.id
        }
      }
      it 'can list all rentals that are currently checked out by customer' do
        # the first customer has one movie checked out
        id = Customer.first.id
        get "/customers/#{id}/current", as: :json
        value(response).must_be :successful?
        fields = %w(checked_out due movie rental_id returned)
        body = JSON.parse(response.body)
        # returns JSON of expected fields, sort fields
        body.each do |movie|
          expect(movie.keys.sort).must_equal fields.sort
        end

        # count movies in array with nil checkin date
        expect(body.count).must_equal 1
        expect do
          post check_out_path, params: rental, as: :json
        end.must_change 'Rental.count', 1

        get "/customers/#{id}/current", as: :json
        body = JSON.parse(response.body)
        expect(body.count).must_equal 2
      end

      it 'can list all rentals in customers rental history' do
        # the first customer has one movie checked out
        id = Customer.first.id
        # checkout a movie for first customer
        post check_out_path, params: rental, as: :json
        # return movie to provide a history
        post check_in_path, params: rental, as: :json
        # count movies in array with checkin date
        # expect do
        #   post check_in_path, params: rental, as: :json
        # end.wont_change 'Rental.count'

        get "/customers/#{id}/history", as: :json
        value(response).must_be :successful?
        fields = %w(checked_out due movie rental_id returned)
        body = JSON.parse(response.body)
        # returns JSON of expected fields, sort fields


        body.each do |movie|
          expect(movie.keys.sort).must_equal fields.sort
        end
        expect(body.count).must_equal 1
        expect(body.last["movie"]["title"]).must_equal Movie.last.title
      end

    end


  end

end
