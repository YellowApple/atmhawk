require 'singleton'
require 'grape'
require 'json'

class SimpleATM
  include Singleton

  class Error < ::StandardError
    attr_reader :status

    def initialize(msg)
      super msg
      @status = 400
    end
  end

  class OverdrawError < Error
    def initialize
      super "Insufficient funds in ATM"
      @status = 402
    end
  end

  class DenominationError < Error
    attr_reader :value

    def initialize(value)
      super "Invalid bill denomination: #{value}"
      @value = value
    end
  end

  class InvalidQuantityError < Error
    def initialize
      super "Quantities must be positive integers"
    end
  end

  def initialize
    empty
  end

  def telemetry
    {total: total, bills: @bills}
  end

  def empty
    @bills = { 1  => 0,
               2  => 0,
               5  => 0,
               10 => 0,
               25 => 0,
               50 => 0 }
  end

  def total
    @bills.map {|value, quantity| value * quantity}.reduce(0, :+)
  end

  def bills(value, quantity = 0)
    if @bills[value]
      @bills[value] += quantity; @bills[value]
    else
      raise DenominationError.new value
    end
  end

  def deposit(bills)
    # Validate everything first
    bills.map do |b|
      value, quantity = [b['value'], b['quantity']]

      # Try getting the value's count to validate it's a valid denomination...
      bills b['value']

      # ...and make sure the value makes sense
      raise InvalidQuantityError unless quantity.is_a? Integer and quantity > 0
    end

    # Now we've got the green light to make the updates
    bills.map { |b| bills b['value'], b['quantity'] }
  end

  def withdraw(amount)
    # Basic validation on the withdrawl amount
    raise InvalidQuantityError unless amount.is_a? Integer and amount > 0

    remainder = amount
    # We ain't updating yet, because we don't want to have to clean up a mess if
    # we hit an overdraw condition
    output = @bills.sort.reverse.to_h.map do |value, _|
      quantity, remainder = withdrawable value, remainder
      [value, quantity]
    end.to_h.filter {|_,v| v > 0}.map {|v,q| {'value' => v, 'quantity' => q}}

    if remainder > 0
      raise OverdrawError.new
    end

    # Now it's safe to go back through and update the bill counters before
    # returning
    output.map {|row| @bills[row['value']] -= row['quantity']}
    output
  end

  def withdrawable(value, attempt)
    requested = attempt / value
    available = bills(value)
    actual = requested > available ? available : requested
    remainder = attempt - (actual * value)
    [actual, remainder]
  end

  class API < Grape::API
    format :json
    resource :simple do
      desc 'Check telemetry data'
      get do
        begin
          status 200
          SimpleATM.instance.telemetry
        rescue Error => e
          status e.status
          {error: e.message}
        end
      end

      desc 'Deposit bills'
      post :deposit do
        begin
          status 201
          SimpleATM.instance.deposit params[:bills]
        rescue Error => e
          status e.status
          {error: e.message}
        end
      end

      desc 'Withdraw bills'
      post :withdraw do
        begin
          status 200
          SimpleATM.instance.withdraw params[:total]
        rescue Error => e
          status e.status
          {error: e.message}
        end
      end
    end
  end
end
