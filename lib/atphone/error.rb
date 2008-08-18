#!/usr/bin/env ruby

# Raised when phone reports ERROR
#
# Data which was got from phone is stored in ATPhone#data
class ATPhone::Error < Exception
    attr_reader :data

    def initialize(data)
        @data = data

        super
    end
end
