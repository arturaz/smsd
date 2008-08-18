#!/usr/bin/env ruby

# Exception raised when number is invalid
class ATPhone::Number::Invalid < Exception # {{{
    def initialize(number)
        super("Number '#{number}' is invalid.")
    end
end # }}}
