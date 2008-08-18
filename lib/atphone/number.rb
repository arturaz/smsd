#!/usr/bin/env

# Class for storing GSM numbers.
class ATPhone::Number < String # {{{
    require 'atphone/number/invalid'

    # Regexp to check if this is a number
    NUMBER_REGEXP = /^\+?\d+$/

    # Raises exception if number is not in right format
    def initialize(number)
        raise ATPhone::Number::Invalid.new(number) \
            unless NUMBER_REGEXP.match(number)
        
        super(number.gsub(/^(\+*)0*/, '\1'))
    end
end # }}}
