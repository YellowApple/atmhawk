# What is this?

It's a coding test for a Ruby development gig.  It's also an attempt to learn
how Grape works, since I hadn't used it before.

# Can I run it?

Sure!

```sh
bundle install
bundle exec rackup  # And then hit up http://localhost:9292/simple
```

# What does it do?

It implements a very simplistic representation of an ATM.

## GET `/simple`

Pulls ATM telemetry.  Shows how much money is in the machine, both by bills and
by total value.

## POST `/deposit`

Puts money in the ATM.  Takes a JSON request body along the lines of the
following:

```json
{
    "bills": [
        {"value": 1, "quantity": 1000},
        {"value": 2, "quantity": 1000},
        {"value": 5, "quantity": 1000},
        {"value": 10, "quantity": 1000},
        {"value": 25, "quantity": 1000},
        {"value": 50, "quantity": 1000}
    ]
}
```

`value` can be any of 1, 2, 5, 10, 25, 50, and represents the value/denomination
of a bill.  `quantity` is the whole (positive) number of bills of that
denomination to deposit.  Not all denominations need to be provided; `{"bills":
[{"value":50, "quantity":123}]}` is perfectly valid.

Returns a 400 error and an `{"error": "$MESSAGE"}` response body if you try to
deposit an unknown denomination or a non-whole (i.e. negative or non-integer)
quantity (with `$MESSAGE` being either `Invalid bill denomination: $VALUE` or
`Quantities must be positive integers`, respectively).

## POST `/withdraw`

Take money out of the ATM.  Takes a JSON request body along the lines of
`{"total": 123}`; `total` can be any whole (i.e. positive integer) number, so
long as the ATM is able to dispense the requisite number of bills.

Returns a 402 error an an `{"error": "Insufficient funds"}` response body if you
try to make a withdrawl the ATM can't do (either because you're withdrawing more
than what's in the ATM or because it doesn't have enough bills of the right
denominations to give you what you wanted).  Returns a 400 error and an
`{"error": "Quantities must be positive integers"}` response body if you try to
withdraw a non-whole (i.e. negative or non-integer) quantity.

# Where does the data get stored?

In-memory, for now at least.  TODO: brush up on ActiveRecord or some other Ruby
database wrapper.

# Is there a license?

Not this time, at least not yet.  Caveat emptor.
