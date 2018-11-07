class Rental < ApplicationRecord
    # relationships
  belongs_to :customer
  belongs_to :movie

  # validations
  validates :checkout_date, presence: true
  validates :due_date, presence: true

  # custom model methods
  def complete?
    return !self.checkin_date.nil?
  end

  def checkout_data
    movie_id = self[:movie_id]
    rented = Movie.find_by(id: movie_id)
    if rented.inventory_available > 0
      rented.inventory_available -= 1
      rented.save
      self.checkout_date = Date.today
      self.due_date = Date.today + 7
      self.checkin_date = nil
      # self.save
      return self
    else
      return nil
    end
  end

  def checkin_data
    movie_id = self[:movie_id]
    rented = Movie.find_by(id: movie_id)
    rented.inventory_available += 1
    rented.save
    self.checkin_date = Date.today
  end
end



# Rental.new(checkout_date: Date.yesterday, due_date: Date.tomorrow, movie_id: 4, customer_id: 1)
