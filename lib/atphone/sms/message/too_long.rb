#!/usr/bin/env ruby

# Exception thrown if message is too long.
class ATPhone::SMS::Message::TooLong < Exception # {{{
    # _max_ is maximum allowed length
    def initialize(max)
        super("Message is too long (max #{max} symbols)")
    end
end # }}}
